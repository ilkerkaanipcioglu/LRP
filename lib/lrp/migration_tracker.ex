defmodule LRP.MigrationTracker.Manager do
  @moduledoc """
  Geçiş sürecini izleyen katman. (ADR-0005)

  shadow → partial → primary → full_cutover aşamaları.

  ## Kurallar
  1. discrepancy_count sıfıra düşmeden sonraki stage'e geçilemez.
  2. full_cutover için kullanıcı onayı zorunludur — sistem ASLA otomatik geçmez.
  3. primary aşamasında eski provider'a senkron yazmaya devam edilir (geri dönüş garantisi).
  4. full_cutover'a yalnızca kullanıcı açıkça request_cutover/2 çağırdığında geçilir.
  """

  alias LRP.{Repo, MigrationTracker, Event}
  import Ecto.Query

  # ── Tracker Başlatma ──────────────────────────────────────────────────────────

  @doc """
  Yeni bir migration tracker başlatır (shadow aşamasından).

  ## Parametreler
  - `tenant_id`        — tenant UUID
  - `capability_id`    — hangi capability geçiş yapıyor
  - `from_provider_id` — mevcut (kaynak) provider
  - `to_provider_id`   — hedef (yeni) provider
  - `opts`             — [target_cutover_at:, notes:]
  """
  @spec start(binary(), binary(), binary(), binary(), keyword()) ::
          {:ok, MigrationTracker.t()} | {:error, Ecto.Changeset.t()}
  def start(tenant_id, capability_id, from_provider_id, to_provider_id, opts \\ []) do
    %MigrationTracker{}
    |> MigrationTracker.changeset(%{
      tenant_id:        tenant_id,
      capability_id:    capability_id,
      from_provider_id: from_provider_id,
      to_provider_id:   to_provider_id,
      stage:            "shadow",
      started_at:       DateTime.utc_now(),
      target_cutover_at: Keyword.get(opts, :target_cutover_at),
      notes:            Keyword.get(opts, :notes)
    })
    |> Repo.insert()
  end

  # ── Aşama İlerletme ──────────────────────────────────────────────────────────

  @doc """
  Tracker'ı bir sonraki aşamaya ilerletir.
  discrepancy_count > 0 ise geçiş reddedilir.
  full_cutover için request_cutover/2 kullanılmalıdır.

  ## Geçiş Kuralları
  shadow      → partial     (discrepancy_count == 0 ise)
  partial     → primary     (discrepancy_count == 0 ise)
  primary     → (kullanıcı request_cutover çağırmalı)
  full_cutover → son aşama, değiştirilemez
  """
  @spec advance_stage(binary(), binary()) :: {:ok, MigrationTracker.t()} | {:error, term()}
  def advance_stage(tracker_id, actor_id) do
    tracker = Repo.get!(MigrationTracker, tracker_id)

    cond do
      tracker.stage == "full_cutover" ->
        {:error, :already_completed}

      tracker.stage == "primary" ->
        {:error, :user_cutover_required,
         "full_cutover için request_cutover/2 kullanın — sistem otomatik geçiş yapmaz"}

      tracker.discrepancy_count > 0 ->
        {:error, :discrepancies_exist,
         "#{tracker.discrepancy_count} uyuşmazlık var; çözülmeden sonraki aşamaya geçilemez"}

      true ->
        next = next_stage(tracker.stage)

        Repo.transaction(fn ->
          updated =
            tracker
            |> MigrationTracker.changeset(%{stage: next})
            |> Repo.update!()

          %Event{}
          |> Event.changeset(%{
            tenant_id:       tracker.tenant_id,
            event_type:      "migration_stage_advanced",
            source:          "migration_tracker",
            occurred_at:     DateTime.utc_now(),
            payload:         %{
              tracker_id:    tracker_id,
              from_stage:    tracker.stage,
              to_stage:      next,
              advanced_by:   actor_id
            },
            tier:            "DURABLE",
            idempotency_key: "stage-advance-#{tracker_id}-#{next}"
          })
          |> Repo.insert!()

          updated
        end)
    end
  end

  @doc """
  full_cutover geçişi — YALNIZCA kullanıcı tarafından çağrılabilir.
  primary aşamasında discrepancy_count == 0 şartı aranır.

  Başarılı olunca:
  1. Tracker stage → "full_cutover"
  2. completed_at kaydedilir
  3. migration_completed EVENT'i oluşturulur
  """
  @spec request_cutover(binary(), binary()) :: {:ok, MigrationTracker.t()} | {:error, term()}
  def request_cutover(tracker_id, actor_id) do
    tracker = Repo.get!(MigrationTracker, tracker_id)

    cond do
      tracker.stage != "primary" ->
        {:error, :not_in_primary_stage,
         "full_cutover yalnızca 'primary' aşamasından yapılabilir. Mevcut aşama: #{tracker.stage}"}

      tracker.discrepancy_count > 0 ->
        {:error, :discrepancies_exist,
         "#{tracker.discrepancy_count} uyuşmazlık çözülmeden full_cutover yapılamaz"}

      true ->
        now = DateTime.utc_now()

        Repo.transaction(fn ->
          updated =
            tracker
            |> MigrationTracker.changeset(%{stage: "full_cutover", completed_at: now})
            |> Repo.update!()

          %Event{}
          |> Event.changeset(%{
            tenant_id:       tracker.tenant_id,
            event_type:      "migration_completed",
            source:          "migration_tracker",
            occurred_at:     now,
            payload:         %{
              tracker_id:        tracker_id,
              capability_id:     tracker.capability_id,
              from_provider_id:  tracker.from_provider_id,
              to_provider_id:    tracker.to_provider_id,
              approved_by:       actor_id,
              days_total:        DateTime.diff(now, tracker.started_at, :day)
            },
            tier:            "DURABLE",
            idempotency_key: "migration-complete-#{tracker_id}"
          })
          |> Repo.insert!()

          updated
        end)
    end
  end

  # ── Discrepancy Yönetimi ─────────────────────────────────────────────────────

  @doc """
  İki provider arasındaki uyuşmazlığı kaydeder.
  discrepancy_count > 0 olduğu sürece aşama ilerlemez.
  """
  @spec record_discrepancy(binary(), map()) :: {:ok, MigrationTracker.t()} | {:error, term()}
  def record_discrepancy(tracker_id, details \\ %{}) do
    tracker = Repo.get!(MigrationTracker, tracker_id)

    Repo.transaction(fn ->
      updated =
        tracker
        |> MigrationTracker.changeset(%{discrepancy_count: tracker.discrepancy_count + 1})
        |> Repo.update!()

      %Event{}
      |> Event.changeset(%{
        tenant_id:       tracker.tenant_id,
        event_type:      "migration_discrepancy",
        source:          "migration_tracker",
        occurred_at:     DateTime.utc_now(),
        payload:         Map.merge(%{tracker_id: tracker_id}, details),
        tier:            "DURABLE",
        idempotency_key: "discrepancy-#{tracker_id}-#{System.system_time(:millisecond)}"
      })
      |> Repo.insert!()

      updated
    end)
  end

  @doc """
  Bir uyuşmazlığı çözüldü olarak işaretler (discrepancy_count - 1).
  """
  @spec resolve_discrepancy(binary()) :: {:ok, MigrationTracker.t()} | {:error, term()}
  def resolve_discrepancy(tracker_id) do
    tracker = Repo.get!(MigrationTracker, tracker_id)

    if tracker.discrepancy_count <= 0 do
      {:error, :no_discrepancies}
    else
      tracker
      |> MigrationTracker.changeset(%{discrepancy_count: tracker.discrepancy_count - 1})
      |> Repo.update()
    end
  end

  # ── Durum Sorgulama ───────────────────────────────────────────────────────────

  @doc """
  Capability için aktif migration tracker'ı döndürür.
  """
  @spec active_for(binary()) :: MigrationTracker.t() | nil
  def active_for(capability_id) do
    from(mt in MigrationTracker,
      where: mt.capability_id == ^capability_id and mt.stage != "full_cutover",
      order_by: [desc: mt.started_at],
      limit: 1
    )
    |> Repo.one()
  end

  # ── Özel ─────────────────────────────────────────────────────────────────────

  defp next_stage("shadow"),  do: "partial"
  defp next_stage("partial"), do: "primary"
  defp next_stage(other),     do: other
end
