defmodule LRP.Repo.Migrations.CreateConnectorAndSubscriptionTables do
  use Ecto.Migration

  def change do
    create table(:connectors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :type, :string, null: false # "github", "slack", "email", etc.
      add :config, :map, null: false
      add :auth_method, :string, null: false # "oauth2", "api_key", "basic", "webhook_secret"
      add :status, :string, default: "active", null: false

      timestamps()
    end

    create table(:event_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, :binary_id, null: false
      add :actor_id, :binary_id # Abone olan actor
      add :event_type_pattern, :string, null: false # "invoice.*", "agent.decision", "*"
      add :webhook_url, :string, null: false
      add :secret, :string
      add :max_causation_depth, :integer, default: 3
      add :status, :string, default: "active", null: false

      timestamps()
    end

    create index(:connectors, [:tenant_id])
    create index(:event_subscriptions, [:tenant_id])
    create index(:event_subscriptions, [:event_type_pattern])
  end
end
