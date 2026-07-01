defmodule Mix.Tasks.Lrp.Demo do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "Uçtan uca canlı demo — 5 dakikada LRP'yi anlar"

  @moduledoc """
  Sıfırdan tam bir iş akışını adım adım çalıştırır.
  Yatırımcı, müşteri veya yeni geliştirici için 5 dakikalık demo.

  ## Kullanım

      mix lrp.demo

  Her adım ekranda görünür. Sonunda sistem durumu JSON olarak yazdırılır.
  """

  @step_delay 400  # ms arası gecikme (dramatik etki için)

  def run(_args) do
    H.start_app()

    H.banner("LRP — Canlı Demo")
    IO.puts(H.dim("  Bir fatura onay akışını uçtan uca izliyorsunuz...\n"))

    # ── ADIM 1: Tenant ─────────────────────────────────────────────────────────
    step(1, "Tenant oluşturuluyor", "Demo Workspace A.Ş.")
    {:ok, tenant} = LRP.create_tenant(%{
      name:   "Demo Workspace — #{DateTime.utc_now() |> DateTime.to_unix()}",
      status: "active"
    })
    ok("Tenant: #{H.bold(tenant.name)}")
    sleep()

    # ── ADIM 2: Actor'lar ──────────────────────────────────────────────────────
    step(2, "Actor'lar ekleniyor", "İlker (User) + Hermes (Agent)")
    {:ok, human} = LRP.create_actor(%{
      tenant_id: tenant.id, type: "User", name: "İlker", status: "active"
    })
    {:ok, agent} = LRP.create_actor(%{
      tenant_id: tenant.id, type: "Agent", name: "Hermes", status: "active"
    })
    ok("#{human.name} (User) + #{agent.name} (Agent)")
    sleep()

    # ── ADIM 3: Gelen e-posta simülasyonu ─────────────────────────────────────
    step(3, "E-posta simüle ediliyor", "muhasebe@eny.com.tr → fatura onayı")
    {:ok, email_evt} = LRP.log_event(%{
      tenant_id:       tenant.id,
      event_type:      "email_received",
      source:          "email",
      tier:            "DURABLE",
      idempotency_key: "demo:email:#{tenant.id}",
      payload: %{
        "from"    => "muhasebe@eny.com.tr",
        "subject" => "Fatura Onayı — INV-DEMO-001",
        "amount"  => "₺48.000"
      }
    })
    ok("EVENT kaydedildi → tier: DURABLE, id: #{short(email_evt.id)}")
    sleep()

    # ── ADIM 4: Document Object ────────────────────────────────────────────────
    step(4, "Document Object oluşturuluyor", "OBJECT(type: Document)")
    {:ok, fatura} = LRP.create_object(%{
      tenant_id: tenant.id,
      type:      "Document",
      name:      "Fatura — INV-DEMO-001",
      status:    "pending_approval",
      metadata:  %{"amount" => 48_000, "currency" => "TRY", "vendor" => "ENY A.Ş."}
    })
    LRP.relate("Event", email_evt.id, "Document", fatura.id, "triggered")
    ok("OBJECT(#{fatura.type}) → #{fatura.name}")
    sleep()

    # ── ADIM 5: Agent sınıflandırıyor ─────────────────────────────────────────
    step(5, "Agent sınıflandırıyor", "Hermes analiz ediyor...")
    :timer.sleep(600)
    {:ok, agent_evt} = LRP.log_event(%{
      tenant_id:        tenant.id,
      event_type:       "agent_classified",
      source:           "agent_mesh",
      tier:             "DURABLE",
      actor_confidence: 0.87,
      idempotency_key:  "demo:agent:classify:#{tenant.id}",
      payload: %{
        "classification" => "invoice_approval",
        "confidence"     => 0.87,
        "risk"           => "LOW"
      }
    })
    LRP.log_agent_context(%{
      tenant_id:        tenant.id,
      actor_id:         agent.id,
      event_id:         agent_evt.id,
      object_id:        fatura.id,
      reasoning_trace:  "Konu: 'Fatura Onayı' + tutar ₺48.000. Geçmiş: 0 gecikme. Risk: DÜŞÜK.",
      confidence_score: 0.87,
      model_version:    "gemini-2.5-pro",
      prompt_hash:      "sha256:demo_hash_001"
    })
    ok("confidence: #{H.green("0.87")} → AgentContext kaydedildi")
    sleep()

    # ── ADIM 6: PROCESS_TASK ───────────────────────────────────────────────────
    step(6, "PROCESS_TASK oluşturuluyor", "İlker onayına yönlendiriliyor")
    {:ok, task} = LRP.create_process_task(%{
      tenant_id:         tenant.id,
      object_id:         fatura.id,
      assigned_actor_id: human.id,
      process_name:      "Fatura Onayı — INV-DEMO-001",
      state:             "pending_review",
      status:            "pending"
    })
    ok("PROCESS_TASK → assigned: #{human.name}, status: #{H.yellow("pending")}")
    sleep()

    # ── ADIM 7: Durum ─────────────────────────────────────────────────────────
    step(7, "Sistem durumu sorgulanıyor", "mix lrp.status --json")
    :timer.sleep(300)
    counts = LRP.count_all()

    IO.puts("")
    IO.puts(H.bold("  ╔══════════════════════════════════════╗"))
    IO.puts(H.bold("  ║        Demo tamamlandı! ✅            ║"))
    IO.puts(H.bold("  ╚══════════════════════════════════════╝"))
    IO.puts("")
    IO.puts(H.dim("  mix lrp.status --json →"))
    H.json_output(Map.put(counts, :db_status, "ok"))
    IO.puts("")
    IO.puts("  Tenant ID : #{H.dim(tenant.id)}")
    IO.puts("  Task ID   : #{H.dim(task.id)}")
    IO.puts("")
    IO.puts(H.dim("  Sonraki adımlar:"))
    IO.puts(H.dim("    mix lrp.tenant list"))
    IO.puts(H.dim("    mix lrp.object list --tenant #{String.slice(tenant.id, 0, 8)}..."))
    IO.puts(H.dim("    mix lrp.event  list --tenant #{String.slice(tenant.id, 0, 8)}..."))
    IO.puts("")
  end

  # ─── yardımcılar ───────────────────────────────────────────────────────────

  defp step(n, title, detail) do
    IO.puts("[#{H.bold(to_string(n))}] #{H.cyan(title)}")
    IO.puts("    #{H.dim(detail)}")
  end

  defp ok(msg) do
    IO.puts("    #{H.green("✓")} #{msg}")
    IO.puts("")
  end

  defp sleep, do: :timer.sleep(@step_delay)

  defp short(id), do: String.slice(id, 0, 8) <> "…"
end
