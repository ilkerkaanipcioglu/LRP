defmodule Mix.Tasks.Lrp.Status do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "LRP sistem durumunu gösterir [--json]"

  @moduledoc """
  Tüm tabloların kayıt sayısını ve DB bağlantı durumunu gösterir.

  ## Kullanım

      mix lrp.status          # İnsan dostu tablo çıktısı
      mix lrp.status --json   # MCP/agent için JSON çıktı

  ## JSON Çıktı (MCP)

      {"tenants":3,"actors":7,"objects":42,"events":118,"relationships":56,
       "versions":23,"process_tasks":4,"agent_contexts":11,"db_status":"ok"}
  """

  @switches [json: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    json_mode = Keyword.get(opts, :json, false)

    H.start_app()

    counts = LRP.count_all()
    db_status = db_check()

    if json_mode do
      H.json_output(Map.put(counts, :db_status, db_status))
    else
      H.banner("LRP — Sistem Durumu")

      H.table(
        ["Tablo", "Kayıt"],
        [
          ["Tenants",        to_string(counts.tenants)],
          ["Actors",         to_string(counts.actors)],
          ["Objects",        to_string(counts.objects)],
          ["Events",         to_string(counts.events)],
          ["Relationships",  to_string(counts.relationships)],
          ["Versions",       to_string(counts.versions)],
          ["Process Tasks",  to_string(counts.process_tasks)],
          ["Agent Contexts", to_string(counts.agent_contexts)]
        ]
      )

      db_label = if db_status == "ok", do: H.green("✅ SQLite3"), else: H.red("❌ Bağlantı hatası")
      IO.puts("  Veritabanı : #{db_label}")
      IO.puts("")

      if counts.process_tasks > 0 do
        IO.puts(H.yellow("  ⚠  #{counts.process_tasks} bekleyen görev var → mix lrp.tasks (yakında)"))
        IO.puts("")
      end
    end
  end

  defp db_check do
    LRP.list_tenants()
    "ok"
  rescue
    _ -> "error"
  end
end
