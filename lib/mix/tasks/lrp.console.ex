defmodule Mix.Tasks.Lrp.Console do
  use Mix.Task
  alias LRP.CliHelpers, as: H
  alias LRP.Capability.Manager, as: CapManager

  @shortdoc "LRP Console kurulum sihirbazı simülasyonunu çalıştırır"

  @moduledoc """
  LRP Console Web GUI onboarding sihirbazındaki 7 adımlı akışı
  terminal üzerinden simüle eder.

  ## Kullanım

      mix lrp.console
  """

  @step_delay 500

  def run(_args) do
    H.start_app()

    H.banner("LRP Console — Onboarding Wizard")
    IO.puts(H.dim("  Yeni bir şirketi LRP altyapısına bağlayan 7 adımlı kurulum sihirbazı...\n"))

    # ── ADIM 1: Şirket & Proje Hiyerarşisi ──────────────────────────────────────
    step(1, "Şirket & Proje Yapılandırması", "Hangi programların aynı veritabanını paylaşacağı tanımlanıyor...")
    
    {:ok, company} = LRP.create_company(%{name: "Acme Holding"})
    
    {:ok, project1} = LRP.create_project(%{
      company_id: company.id,
      name: "Project 1 (Enterprise Operations)",
      database_url: "sqlite://data/acme_internal.sqlite"
    })
    
    {:ok, project2} = LRP.create_project(%{
      company_id: company.id,
      name: "Project 2 (Digital Storefront)",
      database_url: "sqlite://data/acme_ecommerce.sqlite"
    })

    # ERP ve CRM -> Project 1 (Aynı veritabanını paylaşırlar)
    {:ok, tenant_erp} = LRP.create_tenant(%{name: "Acme ERP", project_id: project1.id})
    {:ok, tenant_crm} = LRP.create_tenant(%{name: "Acme CRM", project_id: project1.id})
    
    # E-Ticaret -> Project 2 (İzole/farklı veritabanı)
    {:ok, tenant_shop} = LRP.create_tenant(%{name: "Acme E-Commerce", project_id: project2.id})

    ok("Şirket Oluşturuldu: #{H.bold(company.name)}")
    ok("Proje 1 (Ortak DB) : #{H.bold(project1.name)}")
    ok("  - Bağlı Tenant: #{H.cyan(tenant_erp.name)}")
    ok("  - Bağlı Tenant: #{H.cyan(tenant_crm.name)}")
    ok("  - Veritabanı Havuzu: #{H.dim(project1.database_url)}")
    ok("Proje 2 (İzole DB) : #{H.bold(project2.name)}")
    ok("  - Bağlı Tenant: #{H.cyan(tenant_shop.name)}")
    ok("  - Veritabanı Havuzu: #{H.dim(project2.database_url)}")
    sleep()

    # ── ADIM 2: Eski Yazılım Analizi ──────────────────────────────────────────
    step(2, "Eski Yazılım Entegrasyonu (Legacy Import)", "Eski kaynak kod yapısı taranıyor...")
    legacy_repo = "https://github.com/acme/legacy-monolith"
    ok("Kaynak Kod Bağlantısı: #{H.cyan(legacy_repo)}")
    ok("LRP Yapay Zeka Önerisi: #{H.green("12 adet entite (Lead, Account, Order vb.) tespit edildi.")}")
    sleep()

    # ── ADIM 3: Hedef Platform ve Dil ──────────────────────────────────────────
    step(3, "Platform & Hedef Dil Seçimi", "LRP'nin kod üretim modeli belirleniyor...")
    ok("Seçilen Dil: #{H.bold("Elixir / Phoenix")} (Önerilen)")
    ok("Aşama Modu : #{H.bold("Design Blueprints (.md)")} + #{H.bold("Auto-Scaffolding")}")
    sleep()

    # ── ADIM 4: Veritabanı Seçimi ─────────────────────────────────────────────
    step(4, "Veritabanı Motoru Seçimi", "Depolama altyapısı belirleniyor...")
    ok("Veritabanı: #{H.bold("PostgreSQL (with Row Level Security - RLS)")} (Önerilen)")
    sleep()

    # ── ADIM 5: AI Ajan & LLM Entegrasyonu ──────────────────────────────────────
    step(5, "Yapay Zeka Karar Katmanı (AI Agent & LLM)", "Ajanların akıl yürütme modeli bağlanıyor...")
    ok("LLM API   : #{H.bold("Gemini 2.5 Pro")} (API Key doğrulandı)")
    ok("AI Agent  : #{H.bold("Hermes Classifier Bot")} (Güven eşiği: 0.85)")
    sleep()

    # ── ADIM 6: Üçüncü Parti Eklentiler (Pluggable Services) ─────────────────────
    step(6, "Harici Servis Eklentileri (Capabilities & Providers)", "İş akışı ve depolama servisleri seçiliyor...")
    
    # file_storage capability oluştur
    {:ok, cap_storage} = CapManager.create_capability(tenant_shop.id, "file_storage",
      interface_contract: %{"upload_file/2" => "Uploads file", "delete_file/1" => "Deletes file"},
      description: "E-Commerce File Manager"
    )

    # Google Drive Provider ekle
    {:ok, prov_gdrive} = CapManager.add_provider(cap_storage.id, "external_app",
      provider_ref: %{
        "client_id" => "acme_gdrive_oauth_id",
        "folder_id" => "ecommerce_invoices"
      },
      version: "1.0.0",
      description: "Google Drive Depolama Entegrasyonu"
    )

    # Aktif et (bind)
    {:ok, actor_system} = LRP.create_actor(%{tenant_id: tenant_shop.id, name: "System Admin", type: "User"})
    {:ok, _} = CapManager.bind(cap_storage.id, prov_gdrive.id, actor_system.id)

    ok("İş Akışı (Workflow) : #{H.bold("Activepieces (Webhook Model)")}")
    ok("Dosya Depolama (Disk) : #{H.bold("Google Drive Plugin")} (Aktif)")
    ok("  - Aktif Provider    : #{H.cyan(prov_gdrive.description)}")
    sleep()

    # ── ADIM 7: GitHub Eşitlemesi ─────────────────────────────────────────────
    step(7, "Sürekli Entegrasyon (Git Sync)", "Üretilen LRP sistem kodunun yazılacağı hedef repo bağlanıyor...")
    target_git = "https://github.com/acme/lrp-acme-ops"
    ok("Hedef Repository: #{H.cyan(target_git)}")
    ok("Senkronizasyon  : #{H.green("Otomatik Git Push aktif edildi.")}")
    sleep()

    # ── ÖZET ──────────────────────────────────────────────────────────────────
    IO.puts("")
    IO.puts(H.bold("  ╔══════════════════════════════════════════════════════════════╗"))
    IO.puts(H.bold("  ║          LRP Workspace Kurulumu Tamamlandı! 🎉               ║"))
    IO.puts(H.bold("  ╚══════════════════════════════════════════════════════════════╝"))
    IO.puts("")
    
    status = %{
      sirket: company.name,
      proje1_operasyon: project1.name,
      proje2_eticaret: project2.name,
      ortak_db_tenants: [tenant_erp.name, tenant_crm.name],
      izole_db_tenant: tenant_shop.name,
      pluggable_storage: prov_gdrive.description,
      status: "workspace_active"
    }

    H.json_output(status)
    IO.puts("")
  end

  defp step(n, title, detail) do
    IO.puts("\n[#{H.bold(to_string(n))}] #{H.cyan(title)}")
    IO.puts("    #{H.dim(detail)}")
  end

  defp ok(msg) do
    IO.puts("    #{H.green("✓")} #{msg}")
  end

  defp sleep, do: :timer.sleep(@step_delay)
end
