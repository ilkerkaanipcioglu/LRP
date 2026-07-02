defmodule Mix.Tasks.Lrp.Demo.Plugin do
  use Mix.Task
  alias LRP.CliHelpers, as: H
  alias LRP.Plugin.Registry, as: PluginRegistry
  alias LRP.Capability.Manager, as: CapManager
  alias LRP.Repo

  @shortdoc "Plugin SDK canlı demosu — eklenti mimarisini çalıştırır"

  @moduledoc """
  Plugin SDK mimarisini (Keşif, Kayıt, Doğrulama ve Yürütme) adım adım gösterir.

  ## Kullanım

      mix lrp.demo.plugin
  """

  @step_delay 600

  def run(_args) do
    H.start_app()

    H.banner("LRP — Plugin SDK Canlı Demo")
    IO.puts(H.dim("  Eklenti mimarisinin dinamik çalışmasını izliyorsunuz...\n"))

    # ── ADIM 1: Eklenti Keşfi ──────────────────────────────────────────────────
    step(1, "Eklentiler Keşfediliyor", "PluginRegistry.discover_plugins/0")
    plugins = PluginRegistry.discover_plugins()
    
    if LRP.Plugins.LocalStorage in plugins do
      ok("Keşfedilen Eklenti: #{H.bold("LRP.Plugins.LocalStorage")} (Local Disk File Storage)")
    else
      IO.puts(H.red("❌ LocalStorage eklentisi bulunamadı!"))
      System.halt(1)
    end
    sleep()

    # ── ADIM 2: Otomatik Kayıt ─────────────────────────────────────────────────
    step(2, "Eklentiler Tenant İçin Kaydediliyor", "Capability ve Standby Provider oluşturuluyor...")
    
    tenant_name = "Plugin Demo A.Ş. — #{System.system_time(:second)}"
    {:ok, tenant} = LRP.create_tenant(%{name: tenant_name})
    {:ok, actor} = LRP.create_actor(%{tenant_id: tenant.id, name: "Sistem Yöneticisi", type: "User"})

    {:ok, providers} = PluginRegistry.register_all(tenant.id)
    
    local_storage_prov =
      Enum.find(providers, fn p ->
        Map.get(p.provider_ref, "module") == "LRP.Plugins.LocalStorage" or
        Map.get(p.provider_ref, :module) == LRP.Plugins.LocalStorage
      end)

    ok("Tenant: #{H.bold(tenant.name)}")
    ok("Oluşturulan Capability: #{H.bold("file_storage")}")
    ok("Kayıt Edilen Provider: #{H.bold(local_storage_prov.description)} (ID: #{short(local_storage_prov.id)}, status: #{H.yellow(local_storage_prov.status)})")
    sleep()

    # ── ADIM 3: Doğrulama ve Rollback Simülasyonu ────────────────────────────────
    step(3, "Hatalı Konfigürasyon Doğrulanıyor (Rollback Koruması)", "Eksik parametreyle (root_path olmadan) bind işlemi deneniyor...")
    
    {:ok, bad_prov} = CapManager.add_provider(local_storage_prov.capability_id, "elixir_module",
      provider_ref: %{module: LRP.Plugins.LocalStorage}, # root_path yok!
      version: "1.0.0"
    )

    case CapManager.bind(local_storage_prov.capability_id, bad_prov.id, actor.id) do
      {:error, reason} ->
        ok("İşlem Başarıyla Engellendi (Rollback yapıldı)!")
        ok("Hata Mesajı: #{H.red(reason)}")
      {:ok, _} ->
        IO.puts(H.red("❌ Hatalı bind işlemine izin verildi! Bu bir hata!"))
        System.halt(1)
    end
    sleep()

    # ── ADIM 4: Doğru Konfigürasyonla Bind ──────────────────────────────────────
    step(4, "Doğru Konfigürasyonla Bind Ediliyor", "root_path parametresi eklenerek bind yapılıyor...")
    
    tmp_path = Path.join([File.cwd!(), "tmp", "demo-uploads"])
    File.mkdir_p!(tmp_path)
    
    # demo klasörünü silmek üzere kaydet
    on_exit_demo = fn ->
      File.rm_rf!(Path.join(File.cwd!(), "tmp"))
    end

    {:ok, good_prov} = CapManager.add_provider(local_storage_prov.capability_id, "elixir_module",
      provider_ref: %{module: LRP.Plugins.LocalStorage, root_path: tmp_path},
      version: "1.0.0"
    )

    {:ok, bind_result} = CapManager.bind(local_storage_prov.capability_id, good_prov.id, actor.id)
    ok("Provider Durumu: #{H.green(bind_result.provider.status)} (aktif)")
    ok("Konfigürasyon (root_path): #{H.dim(tmp_path)}")
    sleep()

    # ── ADIM 5: Dinamik execute_capability ──────────────────────────────────────
    step(5, "Eklenti Üzerinden İşlem Yürütülüyor (execute_capability)", "Dosya yükleme tetikleniyor...")
    
    filename = "lrp_eklenti_demosu.txt"
    content = "Merhaba LRP! Bu dosya bir eklenti (plugin) aracılığıyla yerel diske yazıldı."

    {:ok, {:ok, filepath}} = LRP.execute_capability(tenant.id, "file_storage", "upload_file", [filename, content])
    
    ok("Dosya Yükleme Sonucu: Başarılı!")
    ok("Yazılan Yol: #{H.cyan(filepath)}")
    ok("Dosya İçeriği: '#{H.bold(File.read!(filepath))}'")
    sleep()

    # ── ADIM 6: Eklenti Temizliği ──────────────────────────────────────────────
    step(6, "Dosya Silme Tetikleniyor", "file_storage capability'si üzerinden delete_file çalıştırılıyor...")
    
    {:ok, :ok} = LRP.execute_capability(tenant.id, "file_storage", "delete_file", [filename])
    
    if File.exists?(filepath) do
      IO.puts(H.red("❌ Dosya silinemedi!"))
    else
      ok("Dosya diskten başarıyla silindi!")
    end

    # Geçici dosyaları temizle
    on_exit_demo.()
    sleep()

    IO.puts("")
    IO.puts(H.bold("  ╔══════════════════════════════════════╗"))
    IO.puts(H.bold("  ║    Plugin SDK Demosu Tamamlandı! ✅  ║"))
    IO.puts(H.bold("  ╚══════════════════════════════════════╝"))
    IO.puts("")
    IO.puts("  Tüm eklenti keşif, kayıt, validation ve enjeksiyon aşamaları")
    IO.puts("  başarıyla simüle edilmiştir.")
    IO.puts("")
  end

  defp step(n, title, detail) do
    IO.puts("[#{H.bold(to_string(n))}] #{H.cyan(title)}")
    IO.puts("    #{H.dim(detail)}")
  end

  defp ok(msg) do
    IO.puts("    #{H.green("✓")} #{msg}")
  end

  defp sleep, do: :timer.sleep(@step_delay)

  defp short(id), do: String.slice(id, 0, 8) <> "…"
end
