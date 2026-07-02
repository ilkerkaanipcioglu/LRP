defmodule LRP.PluginTest do
  use ExUnit.Case, async: false
  alias LRP.Repo
  alias LRP.Capability.Manager, as: CapManager
  alias LRP.Plugin.Registry, as: PluginRegistry

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Plugin Test Tenant"})
    {:ok, actor} = LRP.create_actor(%{tenant_id: tenant.id, name: "Admin", type: "User"})

    # Temp path for LocalStorage test uploads
    tmp_path = Path.join([File.cwd!(), "tmp", "plugin-uploads"])
    File.mkdir_p!(tmp_path)

    on_exit(fn ->
      File.rm_rf!(Path.join(File.cwd!(), "tmp"))
    end)

    {:ok, tenant: tenant, actor: actor, tmp_path: tmp_path}
  end

  test "Eklenti keşfi (discover_plugins) LocalStorage eklentisini bulmalıdır" do
    discovered = PluginRegistry.discover_plugins()
    assert LRP.Plugins.LocalStorage in discovered
  end

  test "Eklenti kaydı (register_all) capability ve provider'ları otomatik oluşturur", context do
    tenant_id = context.tenant.id

    assert {:ok, providers} = PluginRegistry.register_all(tenant_id)
    assert length(providers) > 0

    # LocalStorage provider'ının standby modda eklendiğini doğrula
    local_storage_prov =
      Enum.find(providers, fn p ->
        Map.get(p.provider_ref, "module") == "LRP.Plugins.LocalStorage" or
        Map.get(p.provider_ref, :module) == LRP.Plugins.LocalStorage
      end)

    assert local_storage_prov != nil
    assert local_storage_prov.status == "standby"
    assert local_storage_prov.version == "1.0.0"

    # Capability'nin veritabanında oluştuğunu doğrula
    cap = Repo.get!(LRP.Capability, local_storage_prov.capability_id)
    assert cap.capability_type == "file_storage"
  end

  test "Hatalı plugin konfigürasyonu ile bind işlemi başarısız olmalıdır (rollback)", context do
    tenant_id = context.tenant.id
    actor_id = context.actor.id

    # 1. Otomatik kayıt yap
    {:ok, providers} = PluginRegistry.register_all(tenant_id)
    local_storage_prov =
      Enum.find(providers, fn p ->
        Map.get(p.provider_ref, "module") == "LRP.Plugins.LocalStorage" or
        Map.get(p.provider_ref, :module) == LRP.Plugins.LocalStorage
      end)

    # 2. Hatalı konfigürasyona sahip yeni bir provider ekle (root_path yok)
    {:ok, bad_prov} = CapManager.add_provider(local_storage_prov.capability_id, "elixir_module",
      provider_ref: %{module: LRP.Plugins.LocalStorage}, # root_path eksik
      version: "1.0.0"
    )

    # 3. Bind işlemi hata vermeli ve veritabanı işlemi geri alınmalıdır
    assert {:error, reason} = CapManager.bind(local_storage_prov.capability_id, bad_prov.id, actor_id)
    assert reason =~ "Configuration validation failed"
  end

  test "Doğru plugin konfigürasyonu ile bind ve dinamik execute başarıyla çalışmalıdır", context do
    tenant_id = context.tenant.id
    actor_id = context.actor.id

    # 1. Otomatik kayıt yap
    {:ok, providers} = PluginRegistry.register_all(tenant_id)
    local_storage_prov =
      Enum.find(providers, fn p ->
        Map.get(p.provider_ref, "module") == "LRP.Plugins.LocalStorage" or
        Map.get(p.provider_ref, :module) == LRP.Plugins.LocalStorage
      end)

    # 2. Doğru konfigürasyona sahip provider ekle ve bind et
    {:ok, good_prov} = CapManager.add_provider(local_storage_prov.capability_id, "elixir_module",
      provider_ref: %{module: LRP.Plugins.LocalStorage, root_path: context.tmp_path},
      version: "1.0.0"
    )

    assert {:ok, _} = CapManager.bind(local_storage_prov.capability_id, good_prov.id, actor_id)

    # 3. Dosya yükleme capability'sini yürüt (execute_capability)
    filename = "test_invoice.pdf"
    content = "PDF CONTENT BINARY"

    assert {:ok, {:ok, filepath}} = LRP.execute_capability(tenant_id, "file_storage", "upload_file", [filename, content])
    assert File.exists?(filepath)
    assert File.read!(filepath) == content

    # 4. Dosya silme capability'sini yürüt
    assert {:ok, :ok} = LRP.execute_capability(tenant_id, "file_storage", "delete_file", [filename])
    refute File.exists?(filepath)
  end
end
