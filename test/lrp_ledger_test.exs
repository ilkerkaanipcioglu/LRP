defmodule LRP.LedgerTest do
  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Ledger Test Tenant"})
    {:ok, tenant: tenant}
  end

  test "mali dönem açık/kapalı kontrolü ve journal posting akışı", %{tenant: tenant} do
    # 1. Ledger oluştur
    {:ok, ledger} = LRP.create_ledger(%{
      tenant_id: tenant.id,
      scheme: "VUK",
      is_leading: true,
      status: "active"
    })

    # 2. Mali dönemleri oluştur (Temmuz açık, Haziran kapalı)
    {:ok, _period_july} = LRP.create_fiscal_period(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      period_start: ~D[2026-07-01],
      period_end: ~D[2026-07-31],
      status: "open"
    })

    {:ok, _period_june} = LRP.create_fiscal_period(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      period_start: ~D[2026-06-01],
      period_end: ~D[2026-06-30],
      status: "closed"
    })

    # 3. Açık dönemde posting işlemi (Temmuz)
    journal_attrs = %{
      doc_date: ~D[2026-07-02],
      posting_date: ~D[2026-07-02]
    }

    lines = [
      %{account_id: "100.01", debit: 5000.0, credit: 0.0},
      %{account_id: "600.01", debit: 0.0, credit: 5000.0}
    ]

    assert {:ok, %{journal: journal, lines: inserted_lines}} =
             LRP.post_journal(tenant.id, ledger.id, journal_attrs, lines)

    assert journal.posting_date == ~D[2026-07-02]
    assert length(inserted_lines) == 2

    # 4. Kapalı dönemde posting işlemi (Haziran) -> Hata almalı
    june_attrs = %{
      doc_date: ~D[2026-06-15],
      posting_date: ~D[2026-06-15]
    }

    assert {:error, :fiscal_period_closed_or_missing} =
             LRP.post_journal(tenant.id, ledger.id, june_attrs, lines)

    # 5. Tanımsız bir dönemde posting işlemi (Ağustos) -> Hata almalı
    august_attrs = %{
      doc_date: ~D[2026-08-01],
      posting_date: ~D[2026-08-01]
    }

    assert {:error, :fiscal_period_closed_or_missing} =
             LRP.post_journal(tenant.id, ledger.id, august_attrs, lines)
  end

  test "satır validation hatasında transaction rollback olmalı", %{tenant: tenant} do
    {:ok, ledger} = LRP.create_ledger(%{
      tenant_id: tenant.id,
      scheme: "VUK",
      is_leading: true,
      status: "active"
    })

    {:ok, _period} = LRP.create_fiscal_period(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      period_start: ~D[2026-07-01],
      period_end: ~D[2026-07-31],
      status: "open"
    })

    journal_attrs = %{
      doc_date: ~D[2026-07-02],
      posting_date: ~D[2026-07-02]
    }

    # Hatalı yevmiye satırı (negatif debit) -> validation hatası vermeli
    invalid_lines = [
      %{account_id: "100.01", debit: -100.0, credit: 0.0},
      %{account_id: "600.01", debit: 0.0, credit: 100.0}
    ]

    # Transaction içinde patlamalı
    assert_raise MatchError, fn ->
      LRP.post_journal(tenant.id, ledger.id, journal_attrs, invalid_lines)
    end

    # Veritabanında journal kaydı oluşmamış olmalı (rollback doğrulama)
    assert LRP.Repo.all(LRP.Journal) == []
    assert LRP.Repo.all(LRP.JournalLine) == []
  end
end
