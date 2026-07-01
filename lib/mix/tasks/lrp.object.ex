defmodule Mix.Tasks.Lrp.Object do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "Object listele/sorgula: list --tenant <id> [--type X] [--json]"

  @moduledoc """
  LRP Object (nesne) sorgulama arayüzü.

  ## Kullanım

      mix lrp.object list --tenant <id>                  # Tüm nesneler
      mix lrp.object list --tenant <id> --type Document  # Tipe göre filtrele
      mix lrp.object list --tenant <id> --json           # JSON (MCP)
      mix lrp.object get  --id <object_id>               # Tek nesne detayı
      mix lrp.object get  --id <id> --json               # JSON detay

  ## Örnekler

      mix lrp.object list --tenant abc-123
      mix lrp.object list --tenant abc-123 --type Party
      mix lrp.object get  --id def-456
  """

  @switches [json: :boolean, tenant: :string, type: :string, id: :string]

  def run(args) do
    {opts, subargs, _} = OptionParser.parse(args, switches: @switches)
    json_mode = Keyword.get(opts, :json, false)

    H.start_app()

    case subargs do
      ["list" | _] -> cmd_list(opts, json_mode)
      ["get"  | _] -> cmd_get(opts, json_mode)
      _            -> usage()
    end
  end

  # ─── list ──────────────────────────────────────────────────────────────────

  defp cmd_list(opts, json_mode) do
    tenant_id = Keyword.get(opts, :tenant)
    type      = Keyword.get(opts, :type)

    unless tenant_id do
      IO.puts(H.red("❌ --tenant gerekli"))
      System.halt(1)
    end

    objects =
      if type,
        do:   LRP.list_objects_by_tenant_and_type(tenant_id, type),
        else: LRP.list_objects_by_tenant(tenant_id)

    if json_mode do
      H.json_output(Enum.map(objects, &object_to_map/1))
    else
      title = if type, do: "Objects — #{type}", else: "Objects"
      H.banner("LRP — #{title}")

      if objects == [] do
        IO.puts(H.yellow("  Nesne bulunamadı."))
      else
        H.table(
          ["ID", "Tip", "Ad", "Durum"],
          Enum.map(objects, fn o ->
            [H.dim(String.slice(o.id, 0, 8) <> "…"),
             o.type,
             H.truncate(o.name, 35),
             status_label(o.status)]
          end)
        )
        IO.puts(H.dim("  Toplam: #{length(objects)} nesne"))
      end
    end
  end

  # ─── get ───────────────────────────────────────────────────────────────────

  defp cmd_get(opts, json_mode) do
    id = Keyword.get(opts, :id)

    unless id do
      IO.puts(H.red("❌ --id gerekli"))
      System.halt(1)
    end

    object = LRP.get_object_with_items(id)

    if object == nil do
      IO.puts(H.red("❌ Object bulunamadı: #{id}"))
      System.halt(1)
    end

    if json_mode do
      H.json_output(object_to_map(object))
    else
      H.banner("LRP — Object Detayı")
      IO.puts("  ID       : #{object.id}")
      IO.puts("  Tip      : #{object.type}")
      IO.puts("  Ad       : #{object.name}")
      IO.puts("  Durum    : #{status_label(object.status)}")
      IO.puts("  Tenant   : #{object.tenant_id}")
      IO.puts("  Metadata : #{Jason.encode!(object.metadata, pretty: false)}")

      if object.items && length(object.items) > 0 do
        IO.puts("")
        IO.puts(H.bold("  Kalemler (#{length(object.items)})"))
        H.table(
          ["Ad", "Adet", "Birim Değer", "Para Birimi", "Durum"],
          Enum.map(object.items, fn i ->
            [H.truncate(i.name, 30),
             to_string(i.quantity),
             to_string(i.unit_value),
             i.currency || "—",
             i.status]
          end)
        )
      end
    end
  end

  # ─── yardımcılar ───────────────────────────────────────────────────────────

  defp usage do
    IO.puts("""
    #{H.bold("mix lrp.object")} — Object yönetimi

    Komutlar:
      list --tenant <id>               Tüm nesneler
      list --tenant <id> --type X      Tipe göre filtrele
      get  --id <object_id>            Nesne detayı

    Bayraklar:
      --json    MCP/agent JSON çıktısı
    """)
  end

  defp object_to_map(o) do
    %{
      id:         o.id,
      tenant_id:  o.tenant_id,
      type:       o.type,
      name:       o.name,
      status:     o.status,
      metadata:   o.metadata,
      inserted_at: to_string(o.inserted_at)
    }
  end

  defp status_label("active"),           do: H.green("active")
  defp status_label("pending_approval"), do: H.yellow("pending_approval")
  defp status_label("closed"),           do: H.dim("closed")
  defp status_label(other),              do: other
end
