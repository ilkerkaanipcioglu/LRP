defmodule Mix.Tasks.Lrp.Seed do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "LRP'ye demo verisi yükler (idempotent)"

  @moduledoc """
  Harezm Demo A.Ş. tenant'ı altında gerçekçi bir senaryo oluşturur:
    - 1 Tenant
    - 2 Actor (human + agent)
    - 3 Object (Müşteri, Fatura, Klasör)
    - 7 Event (email, agent koordinasyonu, onay isteği)
    - 2 AgentContext kaydı
    - Relationship'ler

  ## Kullanım

      mix lrp.seed           # Veriyi yükle, ekranda göster
      mix lrp.seed --quiet   # Sessiz mod (setup script için)

  Aynı tenant adı varsa atlar — tekrar çalıştırılabilir (idempotent).
  """

  @switches [quiet: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    quiet = Keyword.get(opts, :quiet, false)

    H.start_app()

    unless quiet, do: H.banner("LRP — Demo Verisi Yükleniyor")

    # ── 1. Tenant ──────────────────────────────────────────────────────────────
    tenant =
      case LRP.list_tenants() |> Enum.find(&(&1.name == "Harezm Demo A.Ş.")) do
        nil ->
          {:ok, t} = LRP.create_tenant(%{name: "Harezm Demo A.Ş.", status: "active"})
          unless quiet, do: IO.puts(H.green("✓") <> " Tenant oluşturuldu: #{t.name} (#{t.id})")
          t

        existing ->
          unless quiet, do: IO.puts(H.yellow("→") <> " Tenant zaten var: #{existing.name}")
          existing
      end

    # ── 2. Actor'lar ──────────────────────────────────────────────────────────
    {human, agent} =
      case LRP.list_actors_by_tenant(tenant.id) do
        [] ->
          {:ok, h} = LRP.create_actor(%{
            tenant_id: tenant.id,
            type: "User",
            name: "İlker",
            status: "active"
          })
          {:ok, a} = LRP.create_actor(%{
            tenant_id: tenant.id,
            type: "Agent",
            name: "Hermes",
            status: "active"
          })
          unless quiet do
            IO.puts(H.green("✓") <> " Actor: #{h.name} (User)")
            IO.puts(H.green("✓") <> " Actor: #{a.name} (Agent)")
          end
          {h, a}

        actors ->
          h = Enum.find(actors, &(&1.type == "User"))  || List.first(actors)
          a = Enum.find(actors, &(&1.type == "Agent")) || h
          unless quiet, do: IO.puts(H.yellow("→") <> " Actor'lar zaten var")
          {h, a}
      end

    # ── 3. Object'ler ─────────────────────────────────────────────────────────
    {:ok, musteri} = LRP.create_object(%{
      tenant_id: tenant.id,
      type:      "Party",
      name:      "ENY Teknoloji A.Ş.",
      status:    "active",
      metadata:  %{"vkn" => "1234567890", "city" => "İstanbul"}
    })

    {:ok, fatura} = LRP.create_object(%{
      tenant_id: tenant.id,
      type:      "Document",
      name:      "Fatura #INV-2026-001",
      status:    "pending_approval",
      metadata:  %{"amount" => 75_000, "currency" => "TRY", "due_date" => "2026-07-15"}
    })

    {:ok, klasor} = LRP.create_object(%{
      tenant_id: tenant.id,
      type:      "Folder",
      name:      "ENY — Açık İşlemler",
      status:    "active",
      metadata:  %{"urgency" => "high"}
    })

    unless quiet do
      IO.puts(H.green("✓") <> " Object: #{musteri.name} (Party)")
      IO.puts(H.green("✓") <> " Object: #{fatura.name} (Document)")
      IO.puts(H.green("✓") <> " Object: #{klasor.name} (Folder)")
    end

    # ── 4. Fatura satır kalemi ─────────────────────────────────────────────────
    LRP.create_item(%{
      object_id:  fatura.id,
      name:       "LRP Danışmanlık Hizmeti — Temmuz 2026",
      quantity:   1,
      unit_value: 75_000,
      currency:   "TRY",
      status:     "pending"
    })

    # ── 5. Event'ler ──────────────────────────────────────────────────────────
    {:ok, email_event} = LRP.log_event(%{
      tenant_id:       tenant.id,
      event_type:      "email_received",
      source:          "email",
      tier:            "DURABLE",
      idempotency_key: "seed:email:inv-2026-001",
      payload: %{
        "from"    => "muhasebe@eny.com.tr",
        "subject" => "Fatura Gönderimi — INV-2026-001",
        "body"    => "Merhaba, ekteki faturayı onaylamanızı rica ederiz."
      }
    })

    {:ok, agent_event} = LRP.log_event(%{
      tenant_id:        tenant.id,
      event_type:       "agent_classified",
      source:           "agent_mesh",
      tier:             "DURABLE",
      actor_confidence: 0.87,
      idempotency_key:  "seed:agent:classify:inv-2026-001",
      payload: %{
        "agent_id"       => agent.id,
        "classification" => "invoice_approval",
        "confidence"     => 0.87,
        "action"         => "create_process_task"
      }
    })

    LRP.log_event(%{
      tenant_id:        tenant.id,
      event_type:       "approval_requested",
      source:           "lrp_workflow",
      tier:             "DURABLE",
      idempotency_key:  "seed:approval:inv-2026-001",
      payload: %{
        "requested_from" => human.id,
        "document_id"    => fatura.id,
        "deadline"       => "2026-07-05"
      }
    })

    unless quiet, do: IO.puts(H.green("✓") <> " 3 Event kaydedildi")

    # ── 6. AgentContext ────────────────────────────────────────────────────────
    LRP.log_agent_context(%{
      tenant_id:      tenant.id,
      actor_id:       agent.id,
      event_id:       agent_event.id,
      object_id:      fatura.id,
      reasoning_trace: "E-posta içeriği incelendi. 'Fatura' + tutar tespit edildi. " <>
                       "Müşteri geçmişinde 0 gecikme. Risk: DÜŞÜK. Otomatik onay önerilir.",
      confidence_score: 0.87,
      model_version:  "gemini-2.5-pro",
      prompt_hash:    "sha256:seed_demo_hash_001"
    })

    unless quiet, do: IO.puts(H.green("✓") <> " AgentContext kaydedildi")

    # ── 7. PROCESS_TASK ────────────────────────────────────────────────────────
    LRP.create_process_task(%{
      tenant_id:         tenant.id,
      object_id:         fatura.id,
      assigned_actor_id: human.id,
      name:              "Fatura Onayı — INV-2026-001",
      status:            "pending",
      priority:          "high"
    })

    unless quiet, do: IO.puts(H.green("✓") <> " PROCESS_TASK oluşturuldu (onay bekliyor)")

    # ── 8. İlişkiler ──────────────────────────────────────────────────────────
    LRP.relate("Party",    musteri.id, "Document", fatura.id,  "has_invoice")
    LRP.relate("Folder",   klasor.id,  "Document", fatura.id,  "contains")
    LRP.relate("Event",    email_event.id, "Document", fatura.id, "triggered")

    unless quiet do
      IO.puts(H.green("✓") <> " Relationship'ler kuruldu")
      IO.puts("")
      IO.puts(H.bold("Demo verisi hazır!"))
      IO.puts(H.dim("  Tenant ID : #{tenant.id}"))
      IO.puts(H.dim("  Sonraki   : mix lrp.status"))
      IO.puts(H.dim("            : mix lrp.demo"))
      IO.puts("")
    end

    {:ok, tenant}
  end
end
