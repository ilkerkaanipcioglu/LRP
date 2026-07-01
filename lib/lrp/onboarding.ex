defmodule LRP.Onboarding do
  @moduledoc """
  LRP Onboarding — "Sıfırdan mı, mevcut sistemi mi?" akışını yöneten modül.

  ## Akış
  1. start_wizard/1     → sistem tipini ve çıktı modunu seçer (elixir | md-only)
  2. observe_existing/2 → OBSERVATION_MODE oluşturur, connector bağlar
  3. compute_maturity/1 → MATURITY_SCORE hesaplar ve gösterir
  4. request_activation/1 → kullanıcı "devreye al" dediğinde çağrılır

  ## Önemli Kural
  Sistem ASLA otomatik devreye almaz. MATURITY_SCORE sadece bilgi amaçlıdır.
  Son karar her zaman kullanıcıya aittir (request_activation/1 kullanıcı
  tarafından açıkça çağrılmadan devreye alma gerçekleşmez).
  """

  alias LRP.{Repo, ObservationMode, MaturityScore, Event, Tenant}
  import Ecto.Query

  # ── Wizard Başlatma ──────────────────────────────────────────────────────────

  @doc """
  Onboarding wizard verilerini doğrular ve kayıt altına alır.

  ## Parametreler
  - `attrs` — wizard formundan gelen seçimler:
    - `:tenant_id`   — zorunlu
    - `:system_type` — "new_system" | "existing_system"
    - `:output_mode` — "elixir" | "md-only"
    - `:connector`   — "email" | "webhook" | "none"
    - `:target_system` — mevcut sistem adı (existing_system için)

  ## Dönüş
  - `{:ok, result}` — başarılı; result içinde observation_mode ve ilk maturity_score var
  - `{:error, reason}` — doğrulama hatası
  """
  @spec start_wizard(map()) :: {:ok, map()} | {:error, term()}
  def start_wizard(attrs) do
    with :ok <- validate_wizard_attrs(attrs),
         {:ok, result} <- do_start(attrs) do
      {:ok, result}
    end
  end

  # ── Mevcut Sistem İzleme ─────────────────────────────────────────────────────

  @doc """
  Mevcut bir sistem için OBSERVATION_MODE başlatır.
  Gölge modda paralel izleme başlar; mevcut sistem çalışmaya devam eder.

  ## Parametreler
  - `tenant_id`  — tenant UUID
  - `opts`       — [scope:, purpose:, target_system:, metadata:]
  """
  @spec observe_existing(binary(), keyword()) ::
          {:ok, ObservationMode.t()} | {:error, Ecto.Changeset.t()}
  def observe_existing(tenant_id, opts \\ []) do
    attrs = %{
      tenant_id:     tenant_id,
      scope:         Keyword.get(opts, :scope, "full_system"),
      purpose:       Keyword.get(opts, :purpose, "pre_migration"),
      target_system: Keyword.get(opts, :target_system),
      status:        "active",
      metadata:      Keyword.get(opts, :metadata, %{})
    }

    %ObservationMode{}
    |> ObservationMode.changeset(attrs)
    |> Repo.insert()
  end

  # ── Olgunluk Skoru Hesaplama ─────────────────────────────────────────────────

  @doc """
  Bir ObservationMode için MATURITY_SCORE hesaplar ve kaydeder.
  Sonucu gösterir ama ASLA otomatik devreye almaz.

  ## Hesaplama Mantığı
  - coverage_pct  : Son 30 günde kaç event yakalandı / beklenen event sayısı
  - confidence_avg: Son 30 günde agent_contexts'teki confidence_score ortalaması
  - days_observed : ObservationMode'un yaşı (gün)
  - score         : (coverage_pct/100 * 0.6) + (confidence_avg * 0.4)

  ## Öneri Mantığı (sadece bilgi amaçlı)
  - score >= 0.80 → "ready_to_activate"
  - score >= 0.50 → "activate_partial"
  - score < 0.50  → nil (öneri yok)
  """
  @spec compute_maturity(binary()) :: {:ok, MaturityScore.t()} | {:error, term()}
  def compute_maturity(observation_mode_id) do
    case Repo.get(ObservationMode, observation_mode_id) do
      nil -> {:error, :observation_mode_not_found}
      obs ->
        snapshot = build_snapshot(obs.tenant_id, observation_mode_id)
        attrs    = compute_score_attrs(obs, snapshot)

        %MaturityScore{}
        |> MaturityScore.changeset(attrs)
        |> Repo.insert()
    end
  end

  @doc """
  Kullanıcı "devreye al" kararını verdiğinde çağrılır.
  Sistem bunu ASLA otomatik çağırmaz.

  Başarılı olunca:
  1. ObservationMode status → "completed"
  2. provider_swapped EVENT'i oluşturur
  """
  @spec request_activation(binary(), binary()) :: {:ok, map()} | {:error, term()}
  def request_activation(observation_mode_id, actor_id) do
    case Repo.get(ObservationMode, observation_mode_id) do
      nil ->
        {:error, :observation_mode_not_found}

      obs ->
        Repo.transaction(fn ->
          # 1. ObservationMode'u kapat
          obs
          |> ObservationMode.changeset(%{status: "completed"})
          |> Repo.update!()

          # 2. Aktivasyon event'i oluştur (kullanıcı kararı)
          %Event{}
          |> Event.changeset(%{
            tenant_id:        obs.tenant_id,
            event_type:       "lrp_activated",
            source:           "onboarding",
            occurred_at:      DateTime.utc_now(),
            payload:          %{observation_mode_id: observation_mode_id, activated_by: actor_id},
            tier:             "DURABLE",
            idempotency_key:  "activate-#{observation_mode_id}"
          })
          |> Repo.insert!()

          %{observation_mode: obs, status: "activated"}
        end)
    end
  end

  # ── Durum Sorgulama ───────────────────────────────────────────────────────────

  @doc """
  Bir tenant'ın aktif OBSERVATION_MODE ve son MATURITY_SCORE'unu döndürür.
  CLI ve dashboard bu fonksiyonu kullanarak durum gösterir.
  """
  @spec status(binary()) :: {:ok, map()} | {:error, :not_found}
  def status(tenant_id) do
    case Repo.get_by(ObservationMode, tenant_id: tenant_id, status: "active") do
      nil ->
        {:error, :not_found}

      obs ->
        latest_score =
          from(ms in MaturityScore,
            where: ms.observation_mode_id == ^obs.id,
            order_by: [desc: ms.inserted_at],
            limit: 1
          )
          |> Repo.one()

        {:ok, %{observation_mode: obs, latest_score: latest_score}}
    end
  end

  # ── Özel Fonksiyonlar ─────────────────────────────────────────────────────────

  defp validate_wizard_attrs(attrs) do
    cond do
      is_nil(attrs[:tenant_id]) ->
        {:error, "tenant_id zorunlu"}

      attrs[:system_type] not in ["new_system", "existing_system"] ->
        {:error, "system_type: 'new_system' veya 'existing_system' olmalı"}

      attrs[:output_mode] not in ["elixir", "md-only"] ->
        {:error, "output_mode: 'elixir' veya 'md-only' olmalı (v1)"}

      attrs[:connector] not in ["email", "webhook", "none", nil] ->
        {:error, "connector: 'email', 'webhook' veya 'none' olmalı"}

      true ->
        :ok
    end
  end

  defp do_start(%{system_type: "new_system"} = attrs) do
    {:ok, %{
      system_type: "new_system",
      output_mode: attrs[:output_mode],
      connector:   attrs[:connector],
      message:     "Yeni sistem tasarımı başlatıldı. Çıktı modu: #{attrs[:output_mode]}"
    }}
  end

  defp do_start(%{system_type: "existing_system"} = attrs) do
    with {:ok, obs_mode} <- observe_existing(attrs[:tenant_id],
                              target_system: attrs[:target_system],
                              purpose: "pre_migration") do
      {:ok, %{
        system_type:      "existing_system",
        output_mode:      attrs[:output_mode],
        connector:        attrs[:connector],
        observation_mode: obs_mode,
        message:          """
          Mevcut sistem izleme başlatıldı.
          ObservationMode ID: #{obs_mode.id}
          MATURITY_SCORE sıfırdan başlıyor.
          Devreye alma kararı size aittir — sistem asla otomatik geçiş yapmaz.
          """
      }}
    end
  end

  defp build_snapshot(tenant_id, observation_mode_id) do
    # Son 30 günde yakalanan event sayısı
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)

    event_count =
      from(e in Event,
        where: e.tenant_id == ^tenant_id and e.inserted_at >= ^thirty_days_ago,
        select: count(e.id)
      )
      |> Repo.one() || 0

    # Agent confidence ortalaması (son 30 gün)
    avg_confidence =
      from(e in Event,
        where: e.tenant_id == ^tenant_id and
               e.inserted_at >= ^thirty_days_ago and
               not is_nil(e.actor_confidence),
        select: avg(e.actor_confidence)
      )
      |> Repo.one() || 0.0

    # ObservationMode yaşı
    obs = Repo.get(ObservationMode, observation_mode_id)
    days_observed = if obs do
      DateTime.diff(DateTime.utc_now(), obs.inserted_at, :day)
    else
      0
    end

    %{
      event_count:    event_count,
      avg_confidence: avg_confidence || 0.0,
      days_observed:  days_observed
    }
  end

  defp compute_score_attrs(obs, snapshot) do
    # coverage_pct: olay sayısına dayalı basit kapsam tahmini
    # (gerçek implementasyonda domain'e göre beklenen event sayısıyla karşılaştırılır)
    coverage_pct = min(snapshot.event_count / max(snapshot.days_observed * 10, 1) * 100, 100.0)

    confidence_avg = snapshot.avg_confidence

    # Ağırlıklı skor: %60 kapsam, %40 güven
    score = (coverage_pct / 100.0 * 0.6) + (confidence_avg * 0.4)

    recommendation = cond do
      score >= 0.80 -> "ready_to_activate"
      score >= 0.50 -> "activate_partial"
      true          -> nil
    end

    %{
      tenant_id:          obs.tenant_id,
      observation_mode_id: obs.id,
      score:              Float.round(score, 4),
      coverage_pct:       Float.round(coverage_pct, 2),
      confidence_avg:     Float.round(confidence_avg, 4),
      days_observed:      snapshot.days_observed,
      recommendation:     recommendation,
      snapshot:           snapshot
    }
  end
end
