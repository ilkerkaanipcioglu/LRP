defmodule LRP.InboxTest do
  use ExUnit.Case, async: true

  alias LRP.{Tenant, Actor, Object, Event}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Harezm Test A.Ş."})
    {:ok, tenant: tenant}
  end

  @sample_email %{
    message_id: "msg-2026-001@mail.harezm.com",
    from: "musteri@eny.com.tr",
    to: "lrp@harezm.com",
    subject: "Fatura Onay Talebi - PO-2026-99",
    body: "Merhaba, ekteki faturayı onaylamanızı rica ederim. İyi çalışmalar.",
    received_at: ~U[2026-06-30 11:00:00Z]
  }

  test "email geldi → EVENT ve Document OBJECT oluştu", %{tenant: tenant} do
    assert {:ok, %{event: event, document: document}} =
             LRP.Inbox.ingest_email(tenant.id, @sample_email)

    # EVENT doğru oluştu
    assert event.event_type == "email_received"
    assert event.source == "email"
    assert event.tier == "DURABLE"
    assert event.idempotency_key == "email:msg-2026-001@mail.harezm.com"
    assert event.payload["from"] == "musteri@eny.com.tr"
    assert event.payload["subject"] == "Fatura Onay Talebi - PO-2026-99"

    # Document OBJECT doğru oluştu
    assert document.type == "Document"
    assert document.name == "Fatura Onay Talebi - PO-2026-99"
    assert document.metadata["from"] == "musteri@eny.com.tr"
    assert document.metadata["source"] == "email"

    # Relationship kuruldu (event → document: "triggered")
    rels = LRP.list_relationships("Event", event.id, "triggered")
    assert length(rels) == 1
    assert hd(rels).to_id == document.id
    assert hd(rels).to_entity == "Document"
  end

  test "aynı email ikinci kez gelirse idempotent davranır (duplicate reject)", %{tenant: tenant} do
    {:ok, _first} = LRP.Inbox.ingest_email(tenant.id, @sample_email)

    # İkinci deneme — aynı message_id, farklı içerik olsa bile reddedilir
    assert {:ok, %{event: event, document: document, duplicate: true}} =
             LRP.Inbox.ingest_email_idempotent(tenant.id, @sample_email)

    # Hâlâ doğru event ve document döndü
    assert event.idempotency_key == "email:msg-2026-001@mail.harezm.com"
    assert document.type == "Document"
  end

  test "farklı message_id'ler ayrı OBJECT'ler oluşturur", %{tenant: tenant} do
    email1 = %{@sample_email | message_id: "msg-A@mail.com", subject: "Sipariş A"}
    email2 = %{@sample_email | message_id: "msg-B@mail.com", subject: "Sipariş B"}

    {:ok, %{document: doc1}} = LRP.Inbox.ingest_email(tenant.id, email1)
    {:ok, %{document: doc2}} = LRP.Inbox.ingest_email(tenant.id, email2)

    assert doc1.id != doc2.id
    assert doc1.name == "Sipariş A"
    assert doc2.name == "Sipariş B"
  end
end
