defmodule LRP.Connector.DispatcherTest do
  use ExUnit.Case, async: false # Dispatcher self()'e mesaj atacağı için async: false daha güvenli

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Dispatcher Test Tenant"})
    {:ok, tenant: tenant}
  end

  test "event loglandığında eşleşen webhook abonesine asenkron dispatch edilir", %{tenant: tenant} do
    # 1. invoice.* pattern'lı aktif bir subscription oluştur
    {:ok, sub} = LRP.create_subscription(%{
      tenant_id:          tenant.id,
      event_type_pattern: "invoice.*",
      webhook_url:        "http://mock-webhook/invoice-handler",
      status:             "active"
    })

    # 2. Eşleşmeyen bir event logla (örn: order.created) -> Dispatch edilmemeli
    {:ok, _event_order} = LRP.log_event(%{
      tenant_id:       tenant.id,
      event_type:      "order.created",
      source:          "test",
      tier:            "DURABLE",
      idempotency_key: "dispatch:order:1"
    })

    refute_receive {:mock_webhook_delivery, _, _}, 300

    # 3. Eşleşen bir event logla (örn: invoice.approved) -> Asenkron dispatch edilmeli
    {:ok, event_invoice} = LRP.log_event(%{
      tenant_id:       tenant.id,
      event_type:      "invoice.approved",
      source:          "test",
      tier:            "DURABLE",
      idempotency_key: "dispatch:invoice:1",
      payload:         %{"amount" => 1500}
    })

    # self()'e mock delivery mesajının gelmesini bekle
    assert_receive {:mock_webhook_delivery, url, payload}, 800
    assert url == "http://mock-webhook/invoice-handler"
    assert payload["event_id"] == event_invoice.id
    assert payload["event_type"] == "invoice.approved"
    assert payload["payload"]["amount"] == 1500
    # causation_depth 1 artmış olmalı
    assert payload["payload"]["causation_depth"] == 1
  end

  test "causation depth limiti aşılırsa dispatch edilmez (loop engelleme)", %{tenant: tenant} do
    # max_causation_depth = 2 olan subscription oluştur
    {:ok, _sub} = LRP.create_subscription(%{
      tenant_id:          tenant.id,
      event_type_pattern: "*",
      webhook_url:        "http://mock-webhook/loop-handler",
      max_causation_depth: 2,
      status:             "active"
    })

    # causation_depth = 2 olan event logla -> Dispatcher limiti aşacağı için deliver etmemeli
    {:ok, _event} = LRP.log_event(%{
      tenant_id:       tenant.id,
      event_type:      "some.action",
      source:          "test",
      tier:            "DURABLE",
      idempotency_key: "dispatch:loop:1",
      payload:         %{"causation_depth" => 2}
    })

    refute_receive {:mock_webhook_delivery, _, _}, 400
  end

  test "pattern matching kuralları doğrulaması" do
    assert LRP.match_event_pattern?("*", "any.event") == true
    assert LRP.match_event_pattern?("invoice.*", "invoice.paid") == true
    assert LRP.match_event_pattern?("invoice.*", "invoice.item.added") == true
    assert LRP.match_event_pattern?("invoice.*", "order.created") == false
    assert LRP.match_event_pattern?("user.created", "user.created") == true
    assert LRP.match_event_pattern?("user.created", "user.updated") == false
  end
end
