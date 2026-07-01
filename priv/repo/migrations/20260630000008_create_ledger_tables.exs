defmodule LRP.Repo.Migrations.CreateLedgerTables do
  use Ecto.Migration

  def change do
    create table(:ledgers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :scheme, :string, null: false # "VUK", "IFRS"
      add :is_leading, :boolean, default: false, null: false
      add :status, :string, default: "active", null: false

      timestamps()
    end

    create table(:journals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :ledger_id, :binary_id, null: false
      add :doc_date, :date, null: false
      add :posting_date, :date, null: false
      add :source_event_id, :binary_id # Olay kaynaklı LRP Event ID'si

      timestamps()
    end

    create table(:journal_lines, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :journal_id, :binary_id, null: false
      add :account_id, :string, null: false
      add :debit, :decimal, precision: 18, scale: 4, null: false
      add :credit, :decimal, precision: 18, scale: 4, null: false
      add :currency, :string, default: "TRY", null: false
      add :is_reversed, :boolean, default: false, null: false

      timestamps()
    end

    create table(:fiscal_periods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :ledger_id, :binary_id, null: false
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :status, :string, default: "open", null: false # "open", "closed"

      timestamps()
    end

    create index(:ledgers, [:tenant_id])
    create index(:journals, [:tenant_id, :ledger_id])
    create index(:journal_lines, [:journal_id])
    create index(:fiscal_periods, [:tenant_id, :ledger_id])
  end
end
