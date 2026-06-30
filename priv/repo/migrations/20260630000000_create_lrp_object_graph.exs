defmodule LRP.Repo.Migrations.CreateLRPObjectGraph do
  use Ecto.Migration

  def change do
    # 1. TENANTS
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"

      timestamps()
    end

    # 2. ACTORS
    create table(:actors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false # User, Agent, Webhook, API, Robot
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"

      timestamps()
    end
    create index(:actors, [:tenant_id])

    # 3. OBJECTS
    create table(:objects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false # Party, Resource, Document, Folder, Case
      add :name, :string, null: false
      add :status, :string, null: false, default: "active"
      add :metadata, :map, null: false, default: "{}"
      add :parent_id, references(:objects, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end
    create index(:objects, [:tenant_id])
    create index(:objects, [:parent_id])

    # 4. ITEMS
    create table(:items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :object_id, references(:objects, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_item_id, references(:items, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :quantity, :integer, default: 1
      add :unit_value, :integer, default: 0
      add :currency, :string, default: "TRY"
      add :status, :string, null: false, default: "pending"
      add :metadata, :map, null: false, default: "{}"

      timestamps()
    end
    create index(:items, [:object_id])
    create index(:items, [:parent_item_id])

    # 5. RELATIONSHIPS
    create table(:relationships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_entity, :string, null: false # OBJECT, ACTOR, TENANT vb.
      add :from_id, :binary_id, null: false
      add :to_entity, :string, null: false
      add :to_id, :binary_id, null: false
      add :relationship_type, :string, null: false # contains, assigned_to, thread_parent etc.
      add :valid_from, :utc_datetime, null: false
      add :valid_to, :utc_datetime

      timestamps()
    end
    create index(:relationships, [:from_entity, :from_id])
    create index(:relationships, [:to_entity, :to_id])

    # 6. EVENTS
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :source, :string, null: false # email, slack, chat, agent_mesh
      add :occurred_at, :utc_datetime, null: false
      add :payload, :map, null: false, default: "{}"
      add :tier, :string, null: false, default: "WARM" # HOT, WARM, COLD
      add :parent_id, references(:events, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end
    create index(:events, [:tenant_id])
    create index(:events, [:parent_id])

    # 7. POLICIES
    create table(:policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:actors, type: :binary_id, on_delete: :delete_all), null: false
      add :resource_type, :string, null: false # e.g. "Document", "Resource", "*"
      add :action, :string, null: false # read, write, commit, execute, *
      add :effect, :string, null: false, default: "allow" # allow, deny

      timestamps()
    end
    create index(:policies, [:tenant_id])
    create index(:policies, [:actor_id])

    # 8. PROCESS_TASKS
    create table(:process_tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :process_name, :string, null: false
      add :object_id, references(:objects, type: :binary_id, on_delete: :delete_all), null: false
      add :state, :string, null: false
      add :assigned_actor_id, references(:actors, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, null: false, default: "pending" # pending, running, completed, failed

      timestamps()
    end
    create index(:process_tasks, [:tenant_id])
    create index(:process_tasks, [:object_id])
    create index(:process_tasks, [:assigned_actor_id])

    # 9. VERSIONS
    create table(:versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :object_id, references(:objects, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_version_id, references(:versions, type: :binary_id, on_delete: :nilify_all)
      add :commit_message, :string, null: false
      add :committed_by_actor_id, references(:actors, type: :binary_id, on_delete: :nilify_all), null: false
      add :committed_at, :utc_datetime, null: false
      add :object_snapshot, :map, null: false

      timestamps()
    end
    create index(:versions, [:object_id])
    create index(:versions, [:parent_version_id])
    create index(:versions, [:committed_by_actor_id])
  end
end
