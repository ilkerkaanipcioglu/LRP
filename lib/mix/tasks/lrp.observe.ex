defmodule Mix.Tasks.Lrp.Observe do
  use Mix.Task
  alias LRP.CliHelpers, as: H
  alias LRP.Onboarding

  @shortdoc "Mevcut sistem için gölge izleme (ObservationMode) başlatır"

  @moduledoc """
  Mevcut bir kurumsal sistemi (SAP, Salesforce vb.) LRP üzerinden gölge izlemeye alır.
  Bu komut bir `OBSERVATION_MODE` kaydı açar.

  ## Kullanım

      mix lrp.observe --system sap_ecc --purpose documentation_only --tenant <id>
      mix lrp.observe --system sap_ecc --json --tenant <id>

  ## Seçenekler

      --system    İzlenecek mevcut sistem adı (örn: sap_ecc, salesforce) (zorunlu)
      --purpose   Gözlem amacı (default: pre_migration) (seçenekler: pre_migration, documentation_only)
      --tenant    Hangi tenant altında gözlem yapılacağı (yoksa ilk tenant seçilir)
      --json      MCP/agent için JSON çıktı
  """

  @switches [system: :string, purpose: :string, tenant: :string, json: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    system    = Keyword.get(opts, :system)
    purpose   = Keyword.get(opts, :purpose, "pre_migration")
    json_mode = Keyword.get(opts, :json, false)

    unless system do
      IO.puts(H.red("❌ --system belirtilmesi zorunludur (örn: sap_ecc)"))
      System.halt(1)
    end

    H.start_app()

    tenant_id = resolve_tenant(opts, json_mode)

    case Onboarding.observe_existing(tenant_id, target_system: system, purpose: purpose) do
      {:ok, obs} ->
        if json_mode do
          H.json_output(%{
            status: "success",
            observation_mode_id: obs.id,
            tenant_id: obs.tenant_id,
            target_system: obs.target_system,
            purpose: obs.purpose,
            state: obs.status
          })
        else
          H.banner("LRP — Gözlem Modu Başlatıldı")
          IO.puts("  Durum          : #{H.green("Aktif (Gölge Mod)")}")
          IO.puts("  Gözlem ID      : #{obs.id}")
          IO.puts("  Hedef Sistem   : #{H.bold(obs.target_system)}")
          IO.puts("  Gözlem Amacı   : #{obs.purpose}")
          IO.puts("  Tenant ID      : #{obs.tenant_id}")
          IO.puts("")
          IO.puts(H.dim("  Sistem şu an gelen olayları (EVENT) gölgede dinliyor."))
          IO.puts(H.dim("  Olgunluk durumunu görmek için: mix lrp.maturity --tenant #{obs.tenant_id}"))
          IO.puts("")
        end

      {:error, changeset} ->
        IO.puts(H.red("❌ Gözlem başlatılamadı: #{format_errors(changeset)}"))
        System.halt(1)
    end
  end

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

  defp format_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
    |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
  end
end
