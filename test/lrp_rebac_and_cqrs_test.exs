defmodule LRP.ReBACAndCQRSTest do
  use ExUnit.Case, async: false
  alias LRP.Repo

  setup do
    # Her test öncesi Ecto transaction'ı sıfırlansın (clean database sandbox)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
  end

  test "ReBAC (ADR-0003) - Zanzibar-like relationship checks" do
    # 1. Tenant ve Actor'lar oluştur
    {:ok, tenant} = LRP.create_tenant(%{name: "ReBAC Test Ltd."})
    
    {:ok, actor_alice} = LRP.create_actor(%{tenant_id: tenant.id, name: "Alice", type: "User"})
    {:ok, actor_bob} = LRP.create_actor(%{tenant_id: tenant.id, name: "Bob", type: "User"})

    # 2. Objects (Klasörler ve Belgeler) oluştur
    {:ok, folder_finance} = LRP.create_object(%{tenant_id: tenant.id, name: "Finans Klasörü", type: "Folder"})
    {:ok, doc_invoice} = LRP.create_object(%{tenant_id: tenant.id, name: "Temmuz Faturası", type: "Document"})
    {:ok, group_managers} = LRP.create_object(%{tenant_id: tenant.id, name: "Yöneticiler Grubu", type: "Party"})

    # Alice'i Finans klasörünün sahibi yapalım
    {:ok, _} = LRP.relate("Actor", actor_alice.id, "Object", folder_finance.id, "owner")
    
    # Alice Temmuz faturasının sahibi mi? Hayır (Henüz ilişki yok)
    refute LRP.check_permission(actor_alice.id, "owner", doc_invoice.id)

    # Alice'i Temmuz faturasının sahibi yapalım (Direct Relation)
    {:ok, _} = LRP.relate("Actor", actor_alice.id, "Object", doc_invoice.id, "owner")
    assert LRP.check_permission(actor_alice.id, "owner", doc_invoice.id)

    # Implication check: owner olan biri otomatik olarak viewer olmalı
    assert LRP.check_permission(actor_alice.id, "viewer", doc_invoice.id)

    # --- Nested / Transitive Klasör Yetki Kontrolü ---
    # Finans klasörünü faturanın ebeveyni yapalım: folder_finance -> parent -> doc_invoice
    {:ok, _} = LRP.relate("Object", folder_finance.id, "Object", doc_invoice.id, "parent")

    # Bob'u finans klasörünün viewer'ı yapalım
    {:ok, _} = LRP.relate("Actor", actor_bob.id, "Object", folder_finance.id, "viewer")

    # Bob Temmuz faturasını görebilmeli mi? Evet, çünkü ebeveyni olan klasör üzerinde yetkili (Transitive parent)
    assert LRP.check_permission(actor_bob.id, "viewer", doc_invoice.id)
    # Ama Bob sahibi değil veya editörü değil
    refute LRP.check_permission(actor_bob.id, "editor", doc_invoice.id)

    # --- Nested / Transitive Grup Yetki Kontrolü ---
    {:ok, actor_charlie} = LRP.create_actor(%{tenant_id: tenant.id, name: "Charlie", type: "User"})
    
    # Charlie'yi yöneticiler grubuna üye yapalım: charlie -> member -> group_managers
    {:ok, _} = LRP.relate("Actor", actor_charlie.id, "Object", group_managers.id, "member")

    # Yöneticiler grubunu Finans klasörünün editörü yapalım: group_managers -> editor -> folder_finance
    {:ok, _} = LRP.relate("Object", group_managers.id, "Object", folder_finance.id, "editor")

    # Charlie Finans klasörünün editörü mü? Evet (Üyelik -> Grup Yetkisi)
    assert LRP.check_permission(actor_charlie.id, "editor", folder_finance.id)
    # Hiyerarşiden dolayı Charlie faturayı da görebilmeli (Üyelik -> Grup yetkisi -> Klasör editörlüğü -> Belge ebeveynliği)
    assert LRP.check_permission(actor_charlie.id, "viewer", doc_invoice.id)
  end

  test "CQRS (ADR-0001) - Read Model sync and fast views" do
    {:ok, tenant} = LRP.create_tenant(%{name: "CQRS Test Ltd."})
    {:ok, actor_owner} = LRP.create_actor(%{tenant_id: tenant.id, name: "Mali Müşavir", type: "User"})

    # 1. Nesne oluştur ve kalemlerini ekle
    {:ok, object} = LRP.create_object(%{tenant_id: tenant.id, name: "Mal Alım Faturası", type: "Document"})
    
    # Fatura kalemlerini ekle
    {:ok, _} = LRP.create_item(%{object_id: object.id, name: "Ürün A", quantity: 5, unit_value: 120, currency: "TRY"})
    {:ok, _} = LRP.create_item(%{object_id: object.id, name: "Ürün B", quantity: 2, unit_value: 300, currency: "TRY"})

    # Sahip ilişkisi kur (EAV Object Graph)
    {:ok, _} = LRP.relate("Actor", actor_owner.id, "Object", object.id, "owner")

    # 2. Asenkron/Manuel Sync tetikle
    {:ok, read_obj} = LRP.sync_read_model(object.id)

    # 3. CQRS Read modelden anlık oku ve doğrula (Sıfır JOIN)
    assert read_obj.item_count == 2
    assert read_obj.total_value == 1200 # (5 * 120) + (2 * 300) = 600 + 600 = 1200
    assert read_obj.owner_name == "Mali Müşavir"
    assert read_obj.name == "Mal Alım Faturası"

    # Listeleme API testi
    read_list = LRP.list_read_objects(tenant.id)
    assert Enum.count(read_list) == 1
    assert List.first(read_list).total_value == 1200
  end
end
