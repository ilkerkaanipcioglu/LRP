defmodule LRP.JSONPatchVersioningTest do
  use ExUnit.Case, async: false
  alias LRP.Repo
  alias LRP.Version

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Delta Versioning Test"})
    {:ok, actor} = LRP.create_actor(%{tenant_id: tenant.id, name: "Developer", type: "User"})
    {:ok, object} = LRP.create_object(%{tenant_id: tenant.id, name: "Ödeme Modülü", type: "Document"})

    {:ok, tenant: tenant, actor: actor, object: object}
  end

  test "JSON Patch (ADR-0002) - Uçtan uca delta versiyonlama ve Compaction", context do
    actor_id = context.actor.id
    obj_id = context.object.id

    # ─── 1. İlk Commit (Full Snapshot olmalı) ───
    {:ok, v1} = LRP.commit_version(obj_id, actor_id, "İlk kuruluş")
    assert v1.object_snapshot["type"] == "full"
    assert v1.object_snapshot["data"]["name"] == "Ödeme Modülü"
    assert v1.object_snapshot["data"]["status"] == "active"

    # ─── 2. Güncelleme ve İkinci Commit (Delta olmalı) ───
    {:ok, updated_obj} = LRP.update_object(context.object, %{name: "Ödeme Modülü v2", status: "pending"})
    {:ok, v2} = LRP.commit_version(obj_id, actor_id, "v2 güncellemesi")
    assert v2.object_snapshot["type"] == "delta"
    
    # Delta patch içeriğini kontrol et (RFC 6902 formatı)
    patches = v2.object_snapshot["patch"]
    assert Enum.any?(patches, fn p -> p["op"] == "replace" and p["path"] == "/name" and p["value"] == "Ödeme Modülü v2" end)
    assert Enum.any?(patches, fn p -> p["op"] == "replace" and p["path"] == "/status" and p["value"] == "pending" end)

    # ─── 3. Üçüncü Commit (Delta olmalı) ───
    {:ok, _} = LRP.update_object(updated_obj, %{status: "completed", metadata: %{"key" => "value"}})
    {:ok, v3} = LRP.commit_version(obj_id, actor_id, "v3 tamamlandı")
    assert v3.object_snapshot["type"] == "delta"

    # ─── 4. Reconstruct (Snapshot Yeniden İnşa Etme) Doğrulaması ───
    # v1 durumunu doğrula (İlk durum)
    snap1 = LRP.reconstruct_version(v1.id)
    assert snap1["name"] == "Ödeme Modülü"
    assert snap1["status"] == "active"

    # v2 durumunu doğrula (İkinci durum)
    snap2 = LRP.reconstruct_version(v2.id)
    assert snap2["name"] == "Ödeme Modülü v2"
    assert snap2["status"] == "pending"

    # v3 durumunu doğrula (Son durum)
    snap3 = LRP.reconstruct_version(v3.id)
    assert snap3["name"] == "Ödeme Modülü v2"
    assert snap3["status"] == "completed"
    assert snap3["metadata"]["key"] == "value"

    # ─── 5. Compaction (Sıkıştırma) Doğrulaması ───
    # compaction_threshold: 2 vererek commit edeceğiz. 
    # v2 ve v3 delta olduğu için delta_count = 2 olacak.
    # Eşik değerine ulaşıldığı için v4'ün delta değil, FULL snapshot olması gerekir.
    {:ok, _} = LRP.update_object(updated_obj, %{name: "Ödeme Modülü v4 Final"})
    {:ok, v4} = LRP.commit_version(obj_id, actor_id, "v4 final", compaction_threshold: 2)

    assert v4.object_snapshot["type"] == "full"
    assert v4.object_snapshot["data"]["name"] == "Ödeme Modülü v4 Final"
    assert v4.object_snapshot["data"]["status"] == "completed"

    # v4 sonrasındaki bir sonraki commit (v5) tekrar delta olmalı (çünkü v4 full olduğu için delta_count sıfırlandı)
    {:ok, _} = LRP.update_object(updated_obj, %{status: "closed"})
    {:ok, v5} = LRP.commit_version(obj_id, actor_id, "v5 kapandı", compaction_threshold: 2)

    assert v5.object_snapshot["type"] == "delta"

    # Uçtan uca tüm geçmişin geri dönülebilir olduğunu teyit et
    assert LRP.reconstruct_version(v1.id)["name"] == "Ödeme Modülü"
    assert LRP.reconstruct_version(v5.id)["status"] == "closed"
  end
end
