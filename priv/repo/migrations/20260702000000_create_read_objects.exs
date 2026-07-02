defmodule LRP.Repo.Migrations.CreateReadObjects do
  use Ecto.Migration

  def change do
    create table(:read_objects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :type, :string, null: false
      add :name, :string, null: false
      add :status, :string, null: false
      add :metadata, :map
      add :parent_id, :binary_id
      
      # Düzleştirilmiş (flattened) CQRS Raporlama Alanları
      add :owner_name, :string
      add :item_count, :integer, default: 0
      add :total_value, :integer, default: 0

      timestamps()
    end

    create index(:read_objects, [:tenant_id])
    create index(:read_objects, [:tenant_id, :type])
  end
end
