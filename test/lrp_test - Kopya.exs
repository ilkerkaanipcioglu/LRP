defmodule LRPTest do
  use ExUnit.Case, async: true

  alias LRP.{Repo, Tenant, Actor, Object, Item, Relationship, Event, Policy, Version}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
  end

  test "LRP Object Graph MVP: Threads, Attachments, Policies, and Git-like Versioning" do
    # 1. Tenant Oluşturma
    assert {:ok, %Tenant{} = tenant} = LRP.create_tenant(%{name: "Harezm A.Ş."})

    # 2. Actor Oluşturma (AI Agent ve User)
    assert {:ok, %Actor{} = agent} = LRP.create_actor(%{
      tenant_id: tenant.id,
      type: "Agent",
      name: "Hermes Executor"
    })

    assert {:ok, %Actor{} = employee} = LRP.create_actor(%{
      tenant_id: tenant.id,
      type: "User",
      name: "İlker"
    })

    # 3. Kutu / Klasör (Case/Folder) Nesnesi Oluşturma
    assert {:ok, %Object{} = case_folder} = LRP.create_object(%{
      tenant_id: tenant.id,
      type: "Folder",
      name: "Sipariş Klasörü - PO-2026-99",
      metadata: %{"urgency" => "high"}
    })

    # 4. Çok Kanallı Yazışma Normalizasyonu (Slack, Email, A2A Messages)
    # E-posta Olayı
    assert {:ok, %Event{} = email_event} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "email_received",
      source: "email",
      payload: %{"subject" => "Yeni Sipariş Formu Ektedir", "from" => "musteri@eny.com.tr"}
    })

    # Ajanlar Arası (A2A) Olay (AgentMesh)
    assert {:ok, %Event{} = a2a_event} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "agent_coordinated",
      source: "agent_mesh",
      payload: %{"message" => "Sipariş verilerini doğrulamaya başladım", "agent_id" => agent.id}
    })

    # Thread Cevabı (parent_id)
    assert {:ok, %Event{} = a2a_reply} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "agent_coordinated",
      source: "agent_mesh",
      parent_id: a2a_event.id,
      payload: %{"message" => "Veriler onaylandı, fatura oluşturulabilir", "status" => "done"}
    })

    # Olayları Klasöre Bağlama (Relationship)
    assert {:ok, _} = LRP.relate("Folder", case_folder.id, "Event", email_event.id, "contains")
    assert {:ok, _} = LRP.relate("Folder", case_folder.id, "Event", a2a_event.id, "contains")

    # Klasör içindeki olayları listeleme
    relations = LRP.list_relationships("Folder", case_folder.id, "contains")
    assert length(relations) == 2
    assert Enum.any?(relations, fn r -> r.to_id == email_event.id end)
    assert Enum.any?(relations, fn r -> r.to_id == a2a_event.id end)

    # 5. Döküman ve Ekler (Attachments & Itemization)
    assert {:ok, %Object{} = po_doc} = LRP.create_object(%{
      tenant_id: tenant.id,
      type: "Document",
      name: "Sipariş Formu - PO-2026-99"
    })

    # Sipariş satırları (Item) ekleme
    assert {:ok, %Item{} = item1} = LRP.create_item(%{
      object_id: po_doc.id,
      name: "AI Ajan Danışmanlık Hizmeti",
      quantity: 1,
      unit_value: 150000,
      currency: "USD"
    })

    # Siparişi Klasöre/Kutuya Attachment olarak ekleme
    assert {:ok, _} = LRP.relate("Folder", case_folder.id, "Document", po_doc.id, "attachment")

    # 6. Git-like Versioning (Commit Snapshot)
    # İlk Versiyonu Commit Et
    assert {:ok, %Version{} = v1} = LRP.commit_version(po_doc.id, agent.id, "Initial order draft from email")
    assert v1.parent_version_id == nil
    assert v1.object_snapshot["name"] == "Sipariş Formu - PO-2026-99"
    assert length(v1.object_snapshot["items"]) == 1

    # Sleep 1 second to guarantee committed_at difference in SQLite
    Process.sleep(1000)

    # Nesneyi ve Item'ı Güncelle
    assert {:ok, _} = LRP.update_object(po_doc, %{name: "Sipariş Formu - PO-2026-99 (Revize)"})
    assert {:ok, _} = LRP.create_item(%{
      object_id: po_doc.id,
      name: "Ek Lisans Bedeli",
      quantity: 5,
      unit_value: 2000,
      currency: "USD"
    })

    # İkinci Versiyonu Commit Et
    assert {:ok, %Version{} = v2} = LRP.commit_version(po_doc.id, agent.id, "Added license items after review")
    assert v2.parent_version_id == v1.id
    assert v2.object_snapshot["name"] == "Sipariş Formu - PO-2026-99 (Revize)"
    assert length(v2.object_snapshot["items"]) == 2

    # Versiyon Geçmişini sorgulama
    history = LRP.get_version_history(po_doc.id)
    assert length(history) == 2
    assert hd(history).id == v2.id

    # 7. Authorization & Policy Denetimleri
    # Ajan için commit yetkisi tanımla
    assert {:ok, _} = LRP.create_policy(%{
      tenant_id: tenant.id,
      actor_id: agent.id,
      resource_type: "Document",
      action: "commit",
      effect: "allow"
    })

    # Yetkileri doğrula
    assert LRP.authorize(agent.id, "Document", "commit") == :allow
    assert LRP.authorize(employee.id, "Document", "commit") == :deny # Default deny
  end
end
