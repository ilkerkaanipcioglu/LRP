defmodule LRP.Schemas do
  @moduledoc """
  LRP Core Object Graph — 9 çekirdek tablo + Agent-Native uzantılar.

  Çekirdek tablolar: Tenant, Actor, Object, Item, Relationship, Event, Policy, ProcessTask, Version
  Agent-Native uzantılar: AgentContext, AgentCapability
  """
end

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
    field :tenant_id, :binary_id
    field :type, :string  # User, Agent, Webhook, API, Robot
    field :name, :string
    field :status, :string, default: "active"
    timestamps()
  end

  def changeset(actor, attrs) do
    actor
    |> cast(attrs, [:tenant_id, :type, :name, :status])
    |> validate_required([:tenant_id, :type, :name])
  end
end

defmodule LRP.Object do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "objects" do
    field :tenant_id, :binary_id
    field :type, :string   # Party, Resource, Document, Folder, Case
    field :name, :string
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}
    field :parent_id, :binary_id
    field :embedding, :binary  # pgvector(1536) on PostgreSQL; binary on SQLite

    has_many :items, LRP.Item, foreign_key: :object_id
    timestamps()
  end

  def changeset(object, attrs) do
    object
    |> cast(attrs, [:tenant_id, :type, :name, :status, :metadata, :parent_id, :embedding])
    |> validate_required([:tenant_id, :type, :name])
  end
end

defmodule LRP.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "items" do
    field :object_id, :binary_id
    field :parent_item_id, :binary_id
    field :name, :string
    field :quantity, :integer, default: 1
    field :unit_value, :integer, default: 0
    field :currency, :string, default: "TRY"
    field :status, :string, default: "pending"
    field :metadata, :map, default: %{}
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

  def changeset(rel, attrs) do
    rel
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
    field :tenant_id, :binary_id
    field :event_type, :string
    field :source, :string         # email, slack, chat, agent_mesh
    field :occurred_at, :utc_datetime
    field :payload, :map, default: %{}
    field :tier, :string, default: "DURABLE"  # HOT | DURABLE (WARM/COLD ayrımı kaldırıldı)
    field :parent_id, :binary_id

    # Agent-Native alanlar
    field :actor_confidence, :float   # NULL=insan, 0.0-1.0=ajan
    field :idempotency_key, :string   # retry-safe unique key

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:tenant_id, :event_type, :source, :occurred_at, :payload, :tier, :parent_id, :actor_confidence, :idempotency_key])
    |> validate_required([:tenant_id, :event_type, :source])
    |> validate_number(:actor_confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint(:idempotency_key)
  end
end

defmodule LRP.Policy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "policies" do
    field :tenant_id, :binary_id
    field :actor_id, :binary_id
    field :resource_type, :string
    field :action, :string
    field :effect, :string, default: "allow"
    timestamps()
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [:tenant_id, :actor_id, :resource_type, :action, :effect])
    |> validate_required([:tenant_id, :actor_id, :resource_type, :action, :effect])
  end
end

defmodule LRP.ProcessTask do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "process_tasks" do
    field :tenant_id, :binary_id
    field :process_name, :string
    field :object_id, :binary_id
    field :state, :string
    field :assigned_actor_id, :binary_id
    field :status, :string, default: "pending"
    timestamps()
  end

  def changeset(task, attrs) do
    task
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
    field :object_id, :binary_id
    field :parent_version_id, :binary_id
    field :commit_message, :string
    field :committed_by_actor_id, :binary_id
    field :committed_at, :utc_datetime
    field :object_snapshot, :map

    # Agent-Native: ajan tarafından commit edilen versiyonların güven skoru
    field :actor_confidence, :float   # NULL=insan, 0.0-1.0=ajan

    timestamps()
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:object_id, :parent_version_id, :commit_message, :committed_by_actor_id, :committed_at, :object_snapshot, :actor_confidence])
    |> validate_required([:object_id, :commit_message, :committed_by_actor_id, :committed_at, :object_snapshot])
    |> validate_number(:actor_confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end

# ─── Agent-Native Uzantılar ─────────────────────────────────────────────────

defmodule LRP.AgentContext do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Her ajan eyleminin "neden bu kararı verdi" denetim kaydı.
  "Everything is explainable" sloganının ajan kararları için somut karşılığı.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_contexts" do
    field :tenant_id, :binary_id
    field :actor_id, :binary_id
    field :object_id, :binary_id
    field :event_id, :binary_id

    field :reasoning_trace, :string    # LLM'in düşünce zinciri
    field :confidence_score, :float    # 0.0-1.0
    field :model_version, :string      # "gemini-2.0-flash", "claude-4" vb.
    field :prompt_hash, :string        # SHA256 of the prompt sent

    field :inserted_at, :utc_datetime
  end

  def changeset(ctx, attrs) do
    ctx
    |> cast(attrs, [:tenant_id, :actor_id, :object_id, :event_id, :reasoning_trace, :confidence_score, :model_version, :prompt_hash, :inserted_at])
    |> validate_required([:tenant_id, :actor_id])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end

defmodule LRP.AgentCapability do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  MCP-uyumlu Tool/Capability Registry.
  Her ajanın LRP nesneleri üzerinde hangi eylemleri yapabileceğini deklare eder.
  LRP'nin her OBJECT/PROCESS_TASK'ı otomatik olarak MCP tool tanımına dönüşebilir.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agent_capabilities" do
    field :tenant_id, :binary_id
    field :actor_id, :binary_id
    field :tool_name, :string
    field :object_type, :string
    field :process_task_state, :string
    field :mcp_schema, :map, default: %{}
    field :is_active, :boolean, default: true
    timestamps()
  end

  def changeset(cap, attrs) do
    cap
    |> cast(attrs, [:tenant_id, :actor_id, :tool_name, :object_type, :process_task_state, :mcp_schema, :is_active])
    |> validate_required([:tenant_id, :actor_id, :tool_name])
    |> unique_constraint([:tenant_id, :actor_id, :tool_name])
  end
end
