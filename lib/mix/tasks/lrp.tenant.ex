defmodule Mix.Tasks.Lrp.Tenant do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "Tenant yönetimi: list | create --name <ad>"

  @moduledoc """
  LRP tenant yönetimi.

  ## Kullanım

      mix lrp.tenant list                        # Tüm tenant'ları listele
      mix lrp.tenant list --json                 # JSON çıktı (MCP)
      mix lrp.tenant create --name "Şirket Adı" # Yeni tenant oluştur
      mix lrp.tenant create --name "X" --json   # Oluştur + JSON çıktı

  ## Örnekler

      mix lrp.tenant list
      mix lrp.tenant create --name "Harezm A.Ş."
  """

  @switches [json: :boolean, name: :string]

  def run(args) do
    {opts, subargs, _} = OptionParser.parse(args, switches: @switches)
    json_mode = Keyword.get(opts, :json, false)

    H.start_app()

    case subargs do
      ["list" | _]   -> cmd_list(json_mode)
      ["create" | _] -> cmd_create(opts, json_mode)
      _              -> usage()
    end
  end

  # ─── list ──────────────────────────────────────────────────────────────────

  defp cmd_list(json_mode) do
    tenants = LRP.list_tenants()

    if json_mode do
      H.json_output(Enum.map(tenants, &tenant_to_map/1))
    else
      H.banner("LRP — Tenant Listesi")

      if tenants == [] do
        IO.puts(H.yellow("  Henüz tenant yok. → mix lrp.seed"))
      else
        H.table(
          ["ID", "Ad", "Durum", "Oluşturulma"],
          Enum.map(tenants, fn t ->
            [H.dim(String.slice(t.id, 0, 8) <> "…"), t.name, t.status,
             H.format_datetime(t.inserted_at)]
          end)
        )
        IO.puts(H.dim("  Toplam: #{length(tenants)} tenant"))
      end
    end
  end

  # ─── create ────────────────────────────────────────────────────────────────

  defp cmd_create(opts, json_mode) do
    name = Keyword.get(opts, :name)

    unless name do
      IO.puts(H.red("❌ --name gerekli: mix lrp.tenant create --name \"Şirket Adı\""))
      System.halt(1)
    end

    case LRP.create_tenant(%{name: name, status: "active"}) do
      {:ok, tenant} ->
        if json_mode do
          H.json_output(tenant_to_map(tenant))
        else
          IO.puts(H.green("✅ Tenant oluşturuldu"))
          IO.puts("   Ad  : #{tenant.name}")
          IO.puts("   ID  : #{tenant.id}")
          IO.puts("   #{H.dim("Sonraki: mix lrp.tenant list")}")
        end

      {:error, changeset} ->
        IO.puts(H.red("❌ Hata: #{format_errors(changeset)}"))
        System.halt(1)
    end
  end

  # ─── yardımcılar ───────────────────────────────────────────────────────────

  defp usage do
    IO.puts("""
    #{H.bold("mix lrp.tenant")} — Tenant yönetimi

    Komutlar:
      list              Tüm tenant'ları listele
      create --name X   Yeni tenant oluştur

    Bayraklar:
      --json            MCP/agent için JSON çıktı
    """)
  end

  defp tenant_to_map(t) do
    %{id: t.id, name: t.name, status: t.status,
      inserted_at: to_string(t.inserted_at)}
  end

  defp format_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
    |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
  end
end
