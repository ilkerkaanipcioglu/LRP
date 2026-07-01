defmodule LRPTest do
  use ExUnit.Case, async: true

  alias LRP.{Repo, Tenant, Actor, Object, Item, Relationship, Event, Policy, Version, ProcessTask}
  alias LRP.{AgentContext, AgentCapability}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
  end

  test "LRP Object Graph MVP: Agent-Native Flow with Confidence, Context and Capabilities" do
    # 1. Tenant
    assert {:ok, %Tenant{} = tenant} = LRP.create_tenant(%{name: "Harezm A.Ş."})

    # 2. Actor'lar (AI Agent ve User)
    assert {:ok, %Actor{} = agent} = LRP.create_actor(%{
      tenant_id: tenant.id, type: "Agent", name: "Hermes Executor"
    })
    assert {:ok, %Actor{} = employee} = LRP.create_actor(%{
      tenant_id: tenant.id, type: "User", name: "İlker"
    })

    # 3. Dijital Klasör (Folder/Case)
    assert {:ok, %Object{} = case_folder} = LRP.create_object(%{
      tenant_id: tenant.id, type: "Folder", name: "Sipariş Klasörü - PO-2026-99",
      metadata: %{"urgency" => "high"}
    })

    # 4. Çok Kanallı Event Normalizasyonu (DURABLE tier, idempotency_key)
    assert {:ok, %Event{} = email_event} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "email_received",
      source: "email",
      tier: "DURABLE",
      idempotency_key: "email-po-2026-99-v1",
      payload: %{"subject" => "Yeni Sipariş Formu Ektedir", "from" => "musteri@eny.com.tr"}
    })

    # 5. Agent to Agent event (HOT tier, confidence score ile)
    assert {:ok, %Event{} = a2a_event} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "agent_coordinated",
      source: "agent_mesh",
      tier: "HOT",
      actor_confidence: 0.87,
      idempotency_key: "a2a-hermes-coordination-001",
      payload: %{"message" => "Sipariş verilerini doğrulamaya başladım", "agent_id" => agent.id}
    })
    assert a2a_event.actor_confidence == 0.87

    # 6. Idempotency: Aynı event tekrar insert edilemez
    assert {:error, changeset} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "email_received",
      source: "email",
      idempotency_key: "email-po-2026-99-v1",  # aynı key
      payload: %{}
    })
    assert changeset.errors[:idempotency_key] != nil

    # 7. Thread cevabı (parent_id)
    assert {:ok, %Event{} = a2a_reply} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "agent_coordinated",
      source: "agent_mesh",
      parent_id: a2a_event.id,
      actor_confidence: 0.95,
      idempotency_key: "a2a-hermes-reply-001",
      payload: %{"message" => "Veriler onaylandı", "status" => "done"}
    })
    assert a2a_reply.parent_id == a2a_event.id

    # 8. Klasöre event bağlama
    assert {:ok, _} = LRP.relate("Folder", case_folder.id, "Event", email_event.id, "contains")
    assert {:ok, _} = LRP.relate("Folder", case_folder.id, "Event", a2a_event.id, "contains")
    relations = LRP.list_relationships("Folder", case_folder.id, "contains")
    assert length(relations) == 2

    # 9. AGENT_CONTEXT — Ajan kararının denetim kaydı ("everything is explainable")
    assert {:ok, %AgentContext{} = ctx} = LRP.log_agent_context(%{
      tenant_id: tenant.id,
      actor_id: agent.id,
      event_id: a2a_event.id,
      reasoning_trace: "Invoice history showed 3 late payments. Risk score: HIGH. Triggering human review.",
      confidence_score: 0.87,
      model_version: "gemini-2.5-pro",
      prompt_hash: "sha256:abc123def456"
    })
    assert ctx.confidence_score == 0.87
    assert ctx.model_version == "gemini-2.5-pro"

    contexts = LRP.get_agent_contexts(agent.id)
    assert length(contexts) == 1

    # 10. AGENT_CAPABILITY — MCP Tool Registry
    assert {:ok, %AgentCapability{} = cap} = LRP.register_capability(%{
      tenant_id: tenant.id,
      actor_id: agent.id,
      tool_name: "approve_invoice",
      object_type: "Document",
      process_task_state: "pending_approval",
      mcp_schema: %{
        "description" => "Approve an invoice document",
        "input_schema" => %{"type" => "object", "properties" => %{"invoice_id" => %{"type" => "string"}}}
      }
    })
    assert cap.tool_name == "approve_invoice"

    caps = LRP.list_capabilities(agent.id)
    assert length(caps) == 1

    # 11. Döküman ve Sipariş Kalemleri
    assert {:ok, %Object{} = po_doc} = LRP.create_object(%{
      tenant_id: tenant.id, type: "Document", name: "Sipariş Formu - PO-2026-99"
    })
    assert {:ok, _item1} = LRP.create_item(%{
      object_id: po_doc.id, name: "AI Ajan Danışmanlık Hizmeti",
      quantity: 1, unit_value: 150000, currency: "USD"
    })
    assert {:ok, _} = LRP.relate("Folder", case_folder.id, "Document", po_doc.id, "attachment")

    # 12. Git-like Version Commit (ajan commit ile actor_confidence)
    assert {:ok, %Version{} = v1} = LRP.commit_version(
      po_doc.id, agent.id, "Initial order draft",
      actor_confidence: 0.92
    )
    assert v1.parent_version_id == nil
    assert v1.actor_confidence == 0.92
    assert v1.object_snapshot["name"] == "Sipariş Formu - PO-2026-99"

    Process.sleep(1000)

    assert {:ok, _} = LRP.update_object(po_doc, %{name: "Sipariş Formu - PO-2026-99 (Revize)"})
    assert {:ok, _item2} = LRP.create_item(%{
      object_id: po_doc.id, name: "Ek Lisans Bedeli",
      quantity: 5, unit_value: 2000, currency: "USD"
    })

    # İnsan commit (actor_confidence: nil/NULL)
    assert {:ok, %Version{} = v2} = LRP.commit_version(
      po_doc.id, employee.id, "Revised by human after review"
    )
    assert v2.parent_version_id == v1.id
    assert v2.actor_confidence == nil  # insan = NULL confidence

    history = LRP.get_version_history(po_doc.id)
    assert length(history) == 2
    assert hd(history).id == v2.id

    # 13. Policy / Authorization
    assert {:ok, _} = LRP.create_policy(%{
      tenant_id: tenant.id, actor_id: agent.id,
      resource_type: "Document", action: "commit", effect: "allow"
    })
    assert LRP.authorize(agent.id, "Document", "commit") == :allow
    assert LRP.authorize(employee.id, "Document", "commit") == :deny

    # 14. Process Task (Workflow CRUD & List)
    assert {:ok, %ProcessTask{} = task} = LRP.create_process_task(%{
      tenant_id: tenant.id,
      process_name: "Sipariş Onay Süreci",
      object_id: po_doc.id,
      state: "draft",
      assigned_actor_id: employee.id,
      status: "pending"
    })
    assert task.process_name == "Sipariş Onay Süreci"
    assert task.state == "draft"

    assert {:ok, updated_task} = LRP.update_process_task(task, %{state: "approved", status: "completed"})
    assert updated_task.state == "approved"
    assert updated_task.status == "completed"

    tasks = LRP.list_process_tasks_by_tenant(tenant.id)
    assert length(tasks) == 1
    assert hd(tasks).id == task.id

    assert LRP.count_process_tasks_by_tenant(tenant.id, "completed") == 1
    assert LRP.count_process_tasks_by_tenant(tenant.id, "pending") == 0
  end

  test "LRP Semantik Graf Sorgulama & Dolaylı İlişki Analizi (get_related_objects ve connected?)" do
    assert {:ok, tenant} = LRP.create_tenant(%{name: "Twenty Graf Workspace"})

    # Varlıkları Oluştur (Company, Person, Opportunity)
    assert {:ok, comp} = LRP.create_object(%{tenant_id: tenant.id, type: "Company", name: "Acme Corp"})
    assert {:ok, pers} = LRP.create_object(%{tenant_id: tenant.id, type: "Person", name: "John Doe"})
    assert {:ok, opp} = LRP.create_object(%{tenant_id: tenant.id, type: "Opportunity", name: "Acme Big Deal"})
    assert {:ok, unrelated} = LRP.create_object(%{tenant_id: tenant.id, type: "Company", name: "Unrelated LLC"})

    # İlişkileri Kur (Company -> Person, Company -> Opportunity)
    assert {:ok, _} = LRP.relate("Company", comp.id, "Person", pers.id, "has_contact")
    assert {:ok, _} = LRP.relate("Company", comp.id, "Opportunity", opp.id, "has_opportunity")

    # 1. get_related_objects doğrula
    related_people = LRP.get_related_objects("Company", comp.id, "Person")
    assert length(related_people) == 1
    assert List.first(related_people).id == pers.id

    related_opps = LRP.get_related_objects("Company", comp.id, "Opportunity")
    assert length(related_opps) == 1
    assert List.first(related_opps).id == opp.id

    # 2. connected? BFS (Direct & Dolaylı yollar) doğrula
    # Direct yol: Company -> Person (derinlik 1)
    assert LRP.connected?(comp.id, pers.id, 1) == true

    # Dolaylı yol: Person -> Company -> Opportunity (derinlik 2)
    assert LRP.connected?(pers.id, opp.id, 2) == true
    assert LRP.connected?(pers.id, opp.id, 1) == false # derinlik 1 yetersiz olmalı

    # Bağımsız nesne testi
    assert LRP.connected?(pers.id, unrelated.id, 3) == false
  end
end

