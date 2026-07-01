defmodule LRP.PostingRuleTest do
  use ExUnit.Case, async: false

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Posting Rule Test Tenant"})
    {:ok, tenant: tenant}
  end

  test "event tetiklendiğinde posting rule eşleşip otomatik yevmiye fişi kesmeli", %{tenant: tenant} do
    # 1. Ledger ve Açık Mali Dönem oluştur
    {:ok, ledger} = LRP.create_ledger(%{
      tenant_id: tenant.id,
      scheme: "VUK",
      is_leading: true,
      status: "active"
    })

    {:ok, _period} = LRP.create_fiscal_period(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      period_start: Date.utc_today() |> Date.add(-15),
      period_end: Date.utc_today() |> Date.add(15),
      status: "open"
    })

    # 2. Posting Rule tanımla: invoice.approved -> 120.01 (B) / 600.01 (A)
    {:ok, _rule} = LRP.create_posting_rule(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      event_type: "invoice.approved",
      debit_account: "120.01",
      credit_account: "600.01",
      amount_path: "amount",
      status: "active"
    })

    # 3. Tetikleyici olay logla (tutar payload içinde)
    {:ok, event} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "invoice.approved",
      source: "sales_app",
      tier: "DURABLE",
      idempotency_key: "posting:invoice:123",
      payload: %{
        "amount" => 75000.0,
        "invoice_no" => "INV-2026-99"
      }
    })

    # 4. Otomatik oluşturulan yevmiye fişini (Journal) sorgula
    journals = LRP.Repo.all(LRP.Journal)
    assert length(journals) == 1
    [journal] = journals
    assert journal.source_event_id == event.id

    # Yevmiye satırlarını sorgula
    lines = LRP.Repo.all(LRP.JournalLine) |> Enum.sort_by(& &1.account_id)
    assert length(lines) == 2

    [line_120, line_600] = lines
    assert line_120.account_id == "120.01"
    assert Decimal.to_float(line_120.debit) == 75000.0
    assert Decimal.to_float(line_120.credit) == 0.0

    assert line_600.account_id == "600.01"
    assert Decimal.to_float(line_600.debit) == 0.0
    assert Decimal.to_float(line_600.credit) == 75000.0
  end

  test "mali dönem kapalıysa otomatik posting reddedilmeli", %{tenant: tenant} do
    {:ok, ledger} = LRP.create_ledger(%{
      tenant_id: tenant.id,
      scheme: "VUK",
      is_leading: true,
      status: "active"
    })

    # Kapalı dönem
    {:ok, _period} = LRP.create_fiscal_period(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      period_start: Date.utc_today() |> Date.add(-15),
      period_end: Date.utc_today() |> Date.add(15),
      status: "closed"
    })

    {:ok, _rule} = LRP.create_posting_rule(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      event_type: "invoice.approved",
      debit_account: "120.01",
      credit_account: "600.01",
      amount_path: "amount",
      status: "active"
    })

    {:ok, _event} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "invoice.approved",
      source: "sales_app",
      tier: "DURABLE",
      idempotency_key: "posting:invoice:456",
      payload: %{
        "amount" => 15000.0
      }
    })

    # Dönem kapalı olduğu için journal oluşturulmamış olmalı
    assert LRP.Repo.all(LRP.Journal) == []
  end
end
