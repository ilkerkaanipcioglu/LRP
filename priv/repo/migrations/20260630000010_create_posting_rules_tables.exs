defmodule LRP.Repo.Migrations.CreatePostingRulesTables do
  use Ecto.Migration

  def change do
    create table(:posting_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :ledger_id, :binary_id, null: false
      add :event_type, :string, null: false # Hangi event tetikleyecek (örn: "invoice.approved")
      add :debit_account, :string, null: false # Borçlu hesap (VUK/IFRS kodu)
      add :credit_account, :string, null: false # Alacaklı hesap
      add :amount_path, :string, null: false # Event payload'ındaki tutar alanının json key'i (örn: "amount")
      add :status, :string, default: "active", null: false

      timestamps()
    end

    create index(:posting_rules, [:tenant_id, :ledger_id])
    create index(:posting_rules, [:event_type])
  end
end
