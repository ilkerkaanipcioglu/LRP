defmodule Mix.Tasks.Lrp.Tasks do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "Bekleyen PROCESS_TASK'ları listeler [--tenant <id>] [--json]"

  @moduledoc """
  LRP PROCESS_TASK yönetim arayüzü.
  Analizden, e-postadan veya ajan kararından oluşturulan görevleri gösterir.

  ## Kullanım

      mix lrp.tasks                          # Tüm tenant'lardaki görevler
      mix lrp.tasks --tenant <id>            # Belirli tenant
      mix lrp.tasks --tenant <id> --pending  # Sadece bekleyenler
      mix lrp.tasks --tenant <id> --json     # MCP/agent JSON çıktı

  ## Durum Açıklamaları

      pending   → Henüz işlenmedi, insan veya ajan onayı bekliyor
      approved  → Onaylandı, uygulanacak
      rejected  → Reddedildi
      completed → Tamamlandı

  ## MCP Kullanımı

      mix lrp.tasks --tenant <id> --json
      → [{"id":"...","name":"...","priority":"high","status":"pending",...}]
  """

  @switches [json: :boolean, tenant: :string, pending: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    json_mode    = Keyword.get(opts, :json, false)
    pending_only = Keyword.get(opts, :pending, false)
    tenant_id    = Keyword.get(opts, :tenant)

    H.start_app()

    tasks = fetch_tasks(tenant_id, pending_only)

    if json_mode do
      H.json_output(Enum.map(tasks, &task_to_map/1))
    else
      H.banner("LRP — Görev Listesi")

      if tasks == [] do
        msg = if pending_only, do: "Bekleyen görev yok ✅", else: "Görev bulunamadı."
        IO.puts("  #{H.green(msg)}")
        IO.puts("")
      else
        # Önceliğe göre sırala: high > medium > low
        sorted = Enum.sort_by(tasks, fn t ->
          case t.priority do
            "high"   -> 0
            "medium" -> 1
            _        -> 2
          end
        end)

        H.table(
          ["#", "Görev", "Öncelik", "Durum", "Oluşturulma"],
          sorted
          |> Enum.with_index(1)
          |> Enum.map(fn {t, i} ->
            [
              to_string(i),
              H.truncate(t.name, 38),
              priority_label(t.priority),
              status_label(t.status),
              H.format_datetime(t.inserted_at)
            ]
          end)
        )

        pending = Enum.count(tasks, &(&1.status == "pending"))
        IO.puts("  #{H.bold(to_string(pending))} bekleyen · #{length(tasks)} toplam")
        IO.puts("")

        if pending > 0 do
          IO.puts(H.yellow("  ⚠  Bekleyen görevler var."))
          IO.puts(H.dim("     Görev detayı için: iex -S mix → LRP.get_process_task(\"<id>\")"))
          IO.puts("")
        end
      end

      unless tenant_id do
        IO.puts(H.dim("  Tenant'a göre filtrele: mix lrp.tasks --tenant <id>"))
        IO.puts("")
      end
    end
  end

  # ─── Veri Çekme ─────────────────────────────────────────────────────────────

  defp fetch_tasks(nil, pending_only) do
    LRP.list_tenants()
    |> Enum.flat_map(fn t ->
      status = if pending_only, do: "pending", else: nil
      LRP.list_process_tasks_by_tenant(t.id, status)
    end)
  end

  defp fetch_tasks(tenant_id, pending_only) do
    status = if pending_only, do: "pending", else: nil
    LRP.list_process_tasks_by_tenant(tenant_id, status)
  end

  # ─── Format ─────────────────────────────────────────────────────────────────

  defp task_to_map(t) do
    desc = (t.metadata || %{}) |> Map.get("description", nil)
    %{
      id:                t.id,
      name:              t.name,
      priority:          t.priority,
      status:            t.status,
      tenant_id:         t.tenant_id,
      object_id:         t.object_id,
      assigned_actor_id: t.assigned_actor_id,
      description:       desc,
      inserted_at:       to_string(t.inserted_at)
    }
  end

  defp priority_label("high"),   do: H.red("● HIGH")
  defp priority_label("medium"), do: H.yellow("● MEDIUM")
  defp priority_label("low"),    do: H.dim("● LOW")
  defp priority_label(other),    do: other

  defp status_label("pending"),   do: H.yellow("pending")
  defp status_label("approved"),  do: H.green("approved")
  defp status_label("completed"), do: H.green("completed")
  defp status_label("rejected"),  do: H.dim("rejected")
  defp status_label(other),       do: other
end
