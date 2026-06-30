defmodule LRP.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tenants" do
    field :name, :string
    field :status, :string, default: "active"

    timestamps()
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :status])
    |> validate_required([:name])
  end
end

defmodule LRP.Actor do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "actors" do
    field :type, :string # User, Agent, Webhook, API, Robot
    field :name, :string
    field :status, :string, default: "active"
    belongs_to :tenant, LRP.Tenant

    timestamps()
  end

  def changeset(actor, attrs) do
    actor
    |> cast(attrs, [:tenant_id, :type, :name, :status])
    |> validate_required([:tenant_id, :type, :name])
    |> validate_inclusion(:type, ["User", "Agent", "Webhook", "API", "Robot"])
  end
end

defmodule LRP.Object do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "objects" do
    field :type, :string # Party, Resource, Document, Folder, Case
    field :name, :string
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}
    belongs_to :tenant, LRP.Tenant
    belongs_to :parent, LRP.Object, foreign_key: :parent_id
    has_many :items, LRP.Item
    has_many :versions, LRP.Version

    timestamps()
  end

  def changeset(object, attrs) do
    object
    |> cast(attrs, [:tenant_id, :type, :name, :status, :metadata, :parent_id])
    |> validate_required([:tenant_id, :type, :name])
    |> validate_inclusion(:type, ["Party", "Resource", "Document", "Folder", "Case"])
  end
end

defmodule LRP.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "items" do
    field :name, :string
    field :quantity, :integer, default: 1
    field :unit_value, :integer, default: 0
    field :currency, :string, default: "TRY"
    field :status, :string, default: "pending"
    field :metadata, :map, default: %{}
    belongs_to :object, LRP.Object
    belongs_to :parent_item, LRP.Item, foreign_key: :parent_item_id

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:object_id, :parent_item_id, :name, :quantity, :unit_value, :currency, :status, :metadata])
    |> validate_required([:object_id, :name])
  end
end

defmodule LRP.Relationship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "relationships" do
    field :from_entity, :string
    field :from_id, :binary_id
    field :to_entity, :string
    field :to_id, :binary_id
    field :relationship_type, :string
    field :valid_from, :utc_datetime
    field :valid_to, :utc_datetime

    timestamps()
  end

  def changeset(relationship, attrs) do
    relationship
    |> cast(attrs, [:from_entity, :from_id, :to_entity, :to_id, :relationship_type, :valid_from, :valid_to])
    |> validate_required([:from_entity, :from_id, :to_entity, :to_id, :relationship_type, :valid_from])
  end
end

defmodule LRP.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "events" do
    field :event_type, :string
    field :source, :string # email, slack, chat, agent_mesh
    field :occurred_at, :utc_datetime
    field :payload, :map, default: %{}
    field :tier, :string, default: "WARM"
    belongs_to :tenant, LRP.Tenant
    belongs_to :parent, LRP.Event, foreign_key: :parent_id

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:tenant_id, :event_type, :source, :occurred_at, :payload, :tier, :parent_id])
    |> validate_required([:tenant_id, :event_type, :source, :occurred_at])
    |> validate_inclusion(:source, ["email", "slack", "chat", "agent_mesh"])
    |> validate_inclusion(:tier, ["HOT", "WARM", "COLD"])
  end
end

defmodule LRP.Policy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "policies" do
    field :resource_type, :string
    field :action, :string
    field :effect, :string, default: "allow"
    belongs_to :tenant, LRP.Tenant
    belongs_to :actor, LRP.Actor

    timestamps()
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [:tenant_id, :actor_id, :resource_type, :action, :effect])
    |> validate_required([:tenant_id, :actor_id, :resource_type, :action])
    |> validate_inclusion(:effect, ["allow", "deny"])
  end
end

defmodule LRP.ProcessTask do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "process_tasks" do
    field :process_name, :string
    field :state, :string
    field :status, :string, default: "pending"
    belongs_to :tenant, LRP.Tenant
    belongs_to :object, LRP.Object
    belongs_to :assigned_actor, LRP.Actor, foreign_key: :assigned_actor_id

    timestamps()
  end

  def changeset(process_task, attrs) do
    process_task
    |> cast(attrs, [:tenant_id, :process_name, :object_id, :state, :assigned_actor_id, :status])
    |> validate_required([:tenant_id, :process_name, :object_id, :state])
  end
end

defmodule LRP.Version do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "versions" do
    field :commit_message, :string
    field :committed_at, :utc_datetime
    field :object_snapshot, :map
    belongs_to :object, LRP.Object
    belongs_to :parent_version, LRP.Version, foreign_key: :parent_version_id
    belongs_to :committed_by_actor, LRP.Actor, foreign_key: :committed_by_actor_id

    timestamps()
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:object_id, :parent_version_id, :commit_message, :committed_by_actor_id, :committed_at, :object_snapshot])
    |> validate_required([:object_id, :commit_message, :committed_by_actor_id, :committed_at, :object_snapshot])
  end
end
