defmodule Mix.Tasks.Lrp.Event do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "Event listele: list --tenant <id> [--limit N] [--json]"

  @moduledoc """
  LRP event akışını sorgular.

  ## Kullanım

      mix lrp.event list --tenant <id>              # Son 20 event
      mix lrp.event list --tenant <id> --limit 50   # Son 50 event
      mix lrp.event list --tenant <id> --json        # JSON (MCP)

  ## JSON Çıktı (MCP)

      [{"id":"...","event_type":"email_received","source":"email","tier":"DURABLE",
        "actor_confidence":null,"occurred_at":"..."}]
  """

  @switches [json: :boolean, tenant: :string, limit: :integer]

  def run(args) do
    {opts, subargs, _} = OptionParser.parse(args, switches: @switches)
    json_mode = Keyword.get(opts, :json, false)

    H.start_app()

    case subargs do
      ["list" | _] -> cmd_list(opts, json_mode)
      _            -> usage()
    end
  end

  defp cmd_list(opts, json_mode) do
    tenant_id = Keyword.get(opts, :tenant)
    limit     = Keyword.get(opts, :limit, 20)

    unless tenant_id do
      IO.puts(H.red("❌ --tenant gerekli"))
      System.halt(1)
    end

    events = LRP.list_recent_events(tenant_id, limit)

    if json_mode do
      H.json_output(Enum.map(events, &event_to_map/1))
    else
      H.banner("LRP — Event Akışı (son #{limit})")

      if events == [] do
        IO.puts(H.yellow("  Henüz event yok. → mix lrp.seed"))
      else
        H.table(
          ["Tip", "Kaynak", "Tier", "Güven", "Zaman"],
          Enum.map(events, fn e ->
            [H.truncate(e.event_type, 25),
             e.source || "—",
             tier_label(e.tier),
             confidence_label(e.actor_confidence),
             H.format_datetime(e.occurred_at)]
          end)
        )
        IO.puts(H.dim("  #{length(events)} event listelendi (en yeni üstte)"))
      end
    end
  end

  defp usage do
    IO.puts("""
    #{H.bold("mix lrp.event")} — Event akışı

    Komutlar:
      list --tenant <id>              Son 20 event
      list --tenant <id> --limit N    Son N event

    Bayraklar:
      --json    MCP/agent JSON çıktısı
    """)
  end

  defp event_to_map(e) do
    %{
      id:               e.id,
      tenant_id:        e.tenant_id,
      event_type:       e.event_type,
      source:           e.source,
      tier:             e.tier,
      actor_confidence: e.actor_confidence,
      idempotency_key:  e.idempotency_key,
      occurred_at:      to_string(e.occurred_at)
    }
  end

  defp tier_label("HOT"),     do: H.yellow("HOT")
  defp tier_label("DURABLE"), do: H.green("DURABLE")
  defp tier_label(other),     do: other

  defp confidence_label(nil),  do: H.dim("insan")
  defp confidence_label(v) when v >= 0.85, do: H.green("#{v}")
  defp confidence_label(v) when v >= 0.60, do: H.yellow("#{v}")
  defp confidence_label(v),                do: H.red("#{v}")
end
