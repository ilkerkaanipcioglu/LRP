defmodule LRP.MockInvoiceService do
  @moduledoc "Mock service for testing dynamic elixir_module provider execution"
  def calc_tax(amount), do: amount * 0.18
end

defmodule LRP.CapabilityExecutionTest do
  use ExUnit.Case, async: false
  import Ecto.Query
  alias LRP.Repo
  alias LRP.Capability.Manager
  alias LRP.ProcessTask
  alias LRP.Event

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Routing Test Tenant"})
    {:ok, actor_human} = LRP.create_actor(%{tenant_id: tenant.id, name: "Ahmet", type: "User"})
    {:ok, actor_agent} = LRP.create_actor(%{tenant_id: tenant.id, name: "Hermes Bot", type: "Agent"})

    {:ok, tenant: tenant, human: actor_human, agent: actor_agent}
  end

  test "Capability Execution Routing (ADR-0004) - internal_md, human ve elixir_module yönlendirmeleri", context do
    tenant_id = context.tenant.id

    # 1. Capability oluştur
    {:ok, cap} = Manager.create_capability(tenant_id, "invoice_processing",
      interface_contract: %{
        "validate_invoice/1" => "faturayı doğrular",
        "approve_invoice/1" => "faturayı onaylar",
        "calc_tax/1" => "kdv hesaplar"
      }
    )

    # ─── Senaryo A: active provider = internal_md (Tasarım Modu) ───
    {:ok, prov_md} = Manager.add_provider(cap.id, "internal_md",
      status: "standby",
      description: "İlk blueprint tasarım belgesi"
    )
    # Aktif provider olarak ata (hot-swap)
    {:ok, _} = Manager.bind(cap.id, prov_md.id, context.human.id)

    # Yürütmeyi tetikle — Blueprint olduğu için hata vermeli ve otomatik suggested task açmalı
    assert {:error, {:manual_blueprint_required, task_id}} =
      LRP.execute_capability(tenant_id, "invoice_processing", "validate_invoice", ["inv_abc123"])

    # Task'in veritabanında suggested durumunda oluştuğunu doğrula
    task = Repo.get!(ProcessTask, task_id)
    assert task.state == "suggested"
    assert task.process_name == "Manual Blueprint Execution"
    assert task.metadata["function"] == "validate_invoice"

    # ─── Senaryo B: active provider = human (İş Gücü Atama) ───
    {:ok, prov_human} = Manager.add_provider(cap.id, "human",
      status: "standby",
      provider_ref: %{"actor_id" => context.human.id},
      description: "Ahmet'e atanmış manuel iş adımı"
    )
    {:ok, _} = Manager.bind(cap.id, prov_human.id, context.human.id)

    # Yürütmeyi tetikle — İnsana atanmış görev hatası vermeli ve assigned task açmalı
    assert {:error, {:assigned_to_human, task_id_human}} =
      LRP.execute_capability(tenant_id, "invoice_processing", "approve_invoice", ["inv_abc123"])

    task_human = Repo.get!(ProcessTask, task_id_human)
    assert task_human.state == "assigned"
    assert task_human.assigned_actor_id == context.human.id
    assert task_human.process_name == "Human Action Workflow"

    # ─── Senaryo C: active provider = elixir_module (Canlı Elixir Kodu) ───
    {:ok, prov_code} = Manager.add_provider(cap.id, "elixir_module",
      status: "standby",
      provider_ref: %{"module" => "LRP.MockInvoiceService"},
      description: "Yerel çalışan Elixir KDV servis motoru"
    )
    {:ok, _} = Manager.bind(cap.id, prov_code.id, context.human.id)

    # Yürütmeyi tetikle — Dynamic apply ile LRP.MockInvoiceService.calc_tax(1000) çalışmalı
    assert {:ok, tax_value} = LRP.execute_capability(tenant_id, "invoice_processing", "calc_tax", [1000])
    assert tax_value == 180.0

    # ─── Senaryo D: active provider = external_app (Harici Entegrasyon) ───
    {:ok, prov_ext} = Manager.add_provider(cap.id, "external_app",
      status: "standby",
      provider_ref: %{"webhook_url" => "https://api.eny.com.tr/v1/invoices"},
      description: "Dış fatura entegrasyonu"
    )
    {:ok, _} = Manager.bind(cap.id, prov_ext.id, context.human.id)

    assert {:ok, :dispatched} = LRP.execute_capability(tenant_id, "invoice_processing", "validate_invoice", ["inv_abc123"])

    # Entegrasyon Event logunu doğrula
    event = Repo.one(from(e in Event, where: e.event_type == "capability_externally_dispatched"))
    assert event.payload["provider_type"] == "external_app"
    assert event.payload["function"] == "validate_invoice"
  end
end
