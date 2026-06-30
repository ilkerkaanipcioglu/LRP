defmodule LRP.Repo.Migrations.CreateAgentCapabilities do
  use Ecto.Migration

  def change do
    # AGENT_CAPABILITY — MCP-uyumlu Tool/Capability Registry
    # Her ajanın LRP nesneleri üzerinde hangi eylemleri yapabileceğini tanımlar.
    # LRP'nin her OBJECT/PROCESS_TASK'ı otomatik olarak MCP tool tanımına dönüşür.
    create table(:agent_capabilities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:actors, type: :binary_id, on_delete: :delete_all), null: false

      add :tool_name, :string, null: false          # "approve_invoice", "create_purchase_order"
      add :object_type, :string                     # hangi OBJECT type üzerinde çalışır
      add :process_task_state, :string              # hangi PROCESS_TASK state'inde tetiklenir
      add :mcp_schema, :map, default: "{}"          # JSONB — MCP tool input_schema tanımı
      add :is_active, :boolean, null: false, default: true

      timestamps()
    end

    create index(:agent_capabilities, [:tenant_id])
    create index(:agent_capabilities, [:actor_id])
    create unique_index(:agent_capabilities, [:tenant_id, :actor_id, :tool_name])
  end
end
