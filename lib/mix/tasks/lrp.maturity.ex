defmodule Mix.Tasks.Lrp.Maturity do
  use Mix.Task
  alias LRP.CliHelpers, as: H
  alias LRP.Onboarding

  @shortdoc "Gözlem altındaki sistemin LRP geçiş olgunluğunu (MaturityScore) gösterir"

  @moduledoc """
  Aktif gölge izleme (ObservationMode) sürecindeki verileri analiz ederek
  MATURITY_SCORE hesaplar ve en son durumu raporlar.

  ## Kullanım

      mix lrp.maturity --tenant <id>
      mix lrp.maturity --tenant <id> --json

  ## Seçenekler

      --tenant    Olgunluk skoru sorgulanacak tenant ID (yoksa ilk tenant seçilir)
      --json      MCP/agent için JSON çıktı
  """

  @switches [tenant: :string, json: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    json_mode = Keyword.get(opts, :json, false)

    H.start_app()

    tenant_id = resolve_tenant(opts, json_mode)

    case Onboarding.status(tenant_id) do
      {:ok, %{observation_mode: obs, latest_score: _latest_score}} ->
        # Her sorgulamada yeni bir anlık skor hesapla ve kaydet
        {:ok, new_score} = Onboarding.compute_maturity(obs.id)
        display_maturity(new_score, obs, json_mode)

      {:ok, %{observation_mode: obs}} ->
        # Henüz skor kaydedilmemişse hesapla
        {:ok, new_score} = Onboarding.compute_maturity(obs.id)
        display_maturity(new_score, obs, json_mode)

      {:error, :not_found} ->
        if json_mode do
          H.json_output(%{status: "error", message: "Aktif bir gölge izleme (ObservationMode) bulunamadı"})
        else
          IO.puts(H.yellow("⚠  Bu tenant için aktif bir gölge izleme (ObservationMode) süreci bulunmamaktadır."))
          IO.puts(H.dim("   Başlatmak için: mix lrp.observe --system <ad>"))
        end
    end
  end

  defp display_maturity(score, obs, true) do
    H.json_output(%{
      tenant_id: score.tenant_id,
      observation_mode_id: score.observation_mode_id,
      target_system: obs.target_system,
      days_observed: score.days_observed,
      coverage_pct: score.coverage_pct,
      confidence_avg: score.confidence_avg,
      maturity_score: score.score,
      recommendation: score.recommendation
    })
  end

  defp display_maturity(score, obs, false) do
    H.banner("LRP — Geçiş Olgunluk Skoru")

    H.table(
      ["Metrik", "Değer"],
      [
        ["Gözlem ID", score.observation_mode_id],
        ["Hedef Sistem", obs.target_system],
        ["Gözlem Süresi (Gün)", to_string(score.days_observed)],
        ["Event Kapsamı", "%" <> to_string(score.coverage_pct)],
        ["Ajan Güven Ortalaması", to_string(score.confidence_avg)],
        ["Toplam Olgunluk Skoru", score_label(score.score)]
      ]
    )

    IO.puts(H.bold("  Öneri: #{rec_label(score.recommendation)}"))
    IO.puts("")

    case score.recommendation do
      "ready_to_activate" ->
        IO.puts(H.green("  ✅ Sistem LRP moduna geçmeye tamamen hazır!"))
        IO.puts(H.dim("     Geçişi onaylamak için: iex -S mix → LRP.Onboarding.request_activation(\"#{obs.id}\", actor_id)"))

      "activate_partial" ->
        IO.puts(H.yellow("  ⚠  Kısmi devreye alma önerilir (Paralel Çalışma)."))
        IO.puts(H.dim("     Bazı event tipleri veya güven oranları henüz tam olgunlaşmamış."))

      _ ->
        IO.puts(H.red("  ❌ Geçiş için henüz yeterli veri veya güven oluşmadı."))
        IO.puts(H.dim("     Gözlem modunda daha fazla olay (EVENT) yakalanması gerekiyor."))
    end
    IO.puts("")
  end

  defp score_label(s) when s >= 0.8, do: H.green(to_string(s))
  defp score_label(s) when s >= 0.5, do: H.yellow(to_string(s))
  defp score_label(s), do: H.red(to_string(s))

  defp rec_label("ready_to_activate"), do: H.green("DEVREYE ALMAYA HAZIR (READY)")
  defp rec_label("activate_partial"), do: H.yellow("KISMİ DEVREYE ALMA (PARTIAL)")
  defp rec_label(_), do: H.red("GÖZLEME DEVAM ET (OBSERVE)")

  defp resolve_tenant(opts, json_mode) do
    case Keyword.get(opts, :tenant) do
      nil ->
        case LRP.list_tenants() do
          [t | _] -> t.id
          [] ->
            unless json_mode, do: IO.puts(H.yellow("  ⚠  Tenant yok, demo seed çalıştırılıyor..."))
            Mix.Task.run("lrp.seed", ["--quiet"])
            List.first(LRP.list_tenants()).id
        end
      id -> id
    end
  end
end
