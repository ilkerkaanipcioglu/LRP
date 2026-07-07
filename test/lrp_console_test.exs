defmodule LRP.ConsoleTest do
  use ExUnit.Case, async: false

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, company} = LRP.create_company(%{name: "Console Test Company"})
    
    {:ok, project_internal} = LRP.create_project(%{
      company_id: company.id,
      name: "Project Internal Ops",
      database_url: "sqlite://internal_test.db"
    })

    {:ok, project_ecommerce} = LRP.create_project(%{
      company_id: company.id,
      name: "Project E-Commerce",
      database_url: "sqlite://ecommerce_test.db"
    })

    {:ok, tenant_erp} = LRP.create_tenant(%{name: "ERP System", project_id: project_internal.id})
    {:ok, tenant_crm} = LRP.create_tenant(%{name: "CRM System", project_id: project_internal.id})
    {:ok, tenant_shop} = LRP.create_tenant(%{name: "E-Commerce", project_id: project_ecommerce.id})

    {:ok,
      company: company,
      project_internal: project_internal,
      project_ecommerce: project_ecommerce,
      tenant_erp: tenant_erp,
      tenant_crm: tenant_crm,
      tenant_shop: tenant_shop
    }
  end

  test "Şirket ve Projeler başarıyla oluşturulmalı ve birbirine bağlanmalıdır", context do
    assert context.company.name == "Console Test Company"
    assert context.project_internal.company_id == context.company.id
    assert context.project_ecommerce.company_id == context.company.id
  end

  test "Proje veritabanı havuzu sorgulama (get_project_database_pool) doğru URL'leri dönmelidir", context do
    assert LRP.get_project_database_pool(context.project_internal.id) == "sqlite://internal_test.db"
    assert LRP.get_project_database_pool(context.project_ecommerce.id) == "sqlite://ecommerce_test.db"
  end

  test "Veritabanı paylaşım sınırları (topology boundary) kurallara uymalıdır", context do
    # ERP ve CRM aynı projeyi ve veritabanı havuzunu paylaşmalıdır
    assert context.tenant_erp.project_id == context.tenant_crm.project_id
    assert LRP.get_project_database_pool(context.tenant_erp.project_id) == LRP.get_project_database_pool(context.tenant_crm.project_id)

    # E-Ticaret ise tamamen izole bir projede ve farklı bir veritabanı havuzunda olmalıdır
    assert context.tenant_shop.project_id != context.tenant_erp.project_id
    assert LRP.get_project_database_pool(context.tenant_shop.project_id) != LRP.get_project_database_pool(context.tenant_erp.project_id)
  end
end
