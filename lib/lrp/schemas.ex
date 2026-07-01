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

# ─── Onboarding & Observation Katmanı ────────────────────────────────────────

defmodule LRP.ObservationMode do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Mevcut bir sistemi gölge modda izleme kaydı.
  Onboarding sihirbazında "mevcut sistemi geliştiriyorum" seçilince oluşturulur.
  purpose=documentation_only olduğunda ajan hiçbir öneri/geçiş tetiklemez.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "observation_modes" do
    field :tenant_id,     :binary_id
    field :scope,         :string   # full_system | specific_process
    field :target_system, :string   # "SAP ECC", "Gmail", "custom"
    field :purpose,       :string   # documentation_only | pre_migration | continuous_shadow
    field :status,        :string, default: "active"  # active | paused | completed
    field :metadata,      :map, default: %{}

    has_many :maturity_scores, LRP.MaturityScore, foreign_key: :observation_mode_id
    timestamps()
  end

  @valid_scopes    ~w(full_system specific_process)
  @valid_purposes  ~w(documentation_only pre_migration continuous_shadow)
  @valid_statuses  ~w(active paused completed)

  def changeset(obs, attrs) do
    obs
    |> cast(attrs, [:tenant_id, :scope, :target_system, :purpose, :status, :metadata])
    |> validate_required([:tenant_id, :scope, :purpose])
    |> validate_inclusion(:scope, @valid_scopes)
    |> validate_inclusion(:purpose, @valid_purposes)
    |> validate_inclusion(:status, @valid_statuses)
  end
end

defmodule LRP.MaturityScore do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  LRP'nin "devreye hazır mı?" ölçümü.
  Kullanıcı bu skoru görerek devreye alma kararını KENDİSİ verir.
  Sistem asla otomatik devreye ALMAZ — recommendation sadece bilgi amaçlıdır.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "maturity_scores" do
    field :tenant_id,           :binary_id
    field :observation_mode_id, :binary_id

    field :score,          :float, default: 0.0  # 0.0 – 1.0
    field :coverage_pct,   :float, default: 0.0  # EVENT'lerin yüzde kaçı yakalanıyor
    field :confidence_avg, :float, default: 0.0  # ajan confidence ortalaması
    field :days_observed,  :integer, default: 0
    # nil | "ready_to_activate" | "activate_partial"
    # Bilgi amaçlı — otomatik devreye alma YAPMAZ
    field :recommendation, :string
    field :snapshot,       :map, default: %{}

    timestamps()
  end

  def changeset(ms, attrs) do
    ms
    |> cast(attrs, [:tenant_id, :observation_mode_id, :score, :coverage_pct,
                    :confidence_avg, :days_observed, :recommendation, :snapshot])
    |> validate_required([:tenant_id, :observation_mode_id])
    |> validate_number(:score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:coverage_pct, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:confidence_avg, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end

# ─── Capability / Provider / Binding (ADR-0004) ───────────────────────────────

defmodule LRP.Capability do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  "Ne yapılıyor?" sözleşmesi. Provider değişse bile bu tanım değişmez.
  interface_contract, provider'ın uyması gereken minimum fonksiyon listesini JSONB olarak tutar.
  internal_md provider_type = .md dosyası; external_app = Gmail/Slack vb.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "capabilities" do
    field :tenant_id,          :binary_id
    field :capability_type,    :string
    field :interface_contract, :map, default: %{}
    field :status,             :string, default: "active"
    field :description,        :string

    has_many :providers, LRP.Provider, foreign_key: :capability_id
    has_one  :provider_binding, LRP.ProviderBinding, foreign_key: :capability_id
    timestamps()
  end

  @valid_statuses ~w(active deprecated)

  def changeset(cap, attrs) do
    cap
    |> cast(attrs, [:tenant_id, :capability_type, :interface_contract, :status, :description])
    |> validate_required([:tenant_id, :capability_type])
    |> validate_inclusion(:status, @valid_statuses)
    |> unique_constraint([:tenant_id, :capability_type])
  end
end

defmodule LRP.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  "Kim/nasıl yapıyor?" — capability'yi gerçekte kimin yaptığını tanımlar.
  provider_type dil-bağımsızdır; LRP provider'ın dilini umursamaz, sadece
  interface_contract'a uyup uymadığına bakar.

  Downgrade = active_provider_id eski provider'a geri çevrilir; provider asla silinmez.
  Eski provider her zaman status=deprecated olarak saklanır (VERSION felsefesiyle tutarlı).
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "providers" do
    field :tenant_id,     :binary_id
    field :capability_id, :binary_id

    # internal_md | external_app | elixir_module | agent | human
    field :provider_type, :string
    # {path:, connector_id:, module:, webhook_url:, ...}
    field :provider_ref,  :map, default: %{}
    field :version,       :string
    field :status,        :string, default: "active"  # active | standby | deprecated
    field :description,   :string

    timestamps()
  end

  @valid_types    ~w(internal_md external_app elixir_module agent human)
  @valid_statuses ~w(active standby deprecated)

  def changeset(prov, attrs) do
    prov
    |> cast(attrs, [:tenant_id, :capability_id, :provider_type, :provider_ref,
                    :version, :status, :description])
    |> validate_required([:tenant_id, :capability_id, :provider_type])
    |> validate_inclusion(:provider_type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
  end
end

defmodule LRP.ProviderBinding do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Hangi provider şu an aktif? active_provider_id değişince hot-swap olur.
  Değişiklik her zaman bir LRP.Event (provider_swapped) üretir — denetim için kritik.
  Bir tenant'ta bir capability için tek bir aktif binding olabilir (unique_index).
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "provider_bindings" do
    field :tenant_id,          :binary_id
    field :capability_id,      :binary_id
    field :active_provider_id, :binary_id
    field :bound_by_actor_id,  :binary_id
    field :bound_at,           :utc_datetime
    field :notes,              :string

    timestamps()
  end

  def changeset(binding, attrs) do
    binding
    |> cast(attrs, [:tenant_id, :capability_id, :active_provider_id,
                    :bound_by_actor_id, :bound_at, :notes])
    |> validate_required([:tenant_id, :capability_id, :active_provider_id, :bound_at])
    |> unique_constraint([:tenant_id, :capability_id])
  end
end

# ─── Migration Tracker (ADR-0005) ─────────────────────────────────────────────

defmodule LRP.MigrationTracker do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Geçişin kendisini izler: shadow → partial → primary → full_cutover.
  discrepancy_count sıfıra düşmeden sonraki stage'e geçilemez.
  full_cutover için kullanıcı onayı zorunludur — sistem asla otomatik geçmez.
  """

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "migration_trackers" do
    field :tenant_id,        :binary_id
    field :capability_id,    :binary_id
    field :from_provider_id, :binary_id
    field :to_provider_id,   :binary_id

    # shadow      → yeni provider izliyor, eski gerçek işi yapıyor
    # partial     → yeni provider bazı düşük riskli işlemleri yapıyor
    # primary     → yeni provider ana, eski yedek/doğrulama
    # full_cutover → kullanıcı onayı sonrası; eski deprecated
    field :stage,             :string, default: "shadow"
    field :coverage_pct,      :float, default: 0.0
    field :discrepancy_count, :integer, default: 0
    field :started_at,        :utc_datetime
    field :target_cutover_at, :utc_datetime
    field :completed_at,      :utc_datetime
    field :notes,             :string

    timestamps()
  end

  @valid_stages ~w(shadow partial primary full_cutover)

  def changeset(tracker, attrs) do
    tracker
    |> cast(attrs, [:tenant_id, :capability_id, :from_provider_id, :to_provider_id,
                    :stage, :coverage_pct, :discrepancy_count, :started_at,
                    :target_cutover_at, :completed_at, :notes])
    |> validate_required([:tenant_id, :capability_id, :from_provider_id, :to_provider_id, :started_at])
    |> validate_inclusion(:stage, @valid_stages)
    |> validate_number(:coverage_pct, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:discrepancy_count, greater_than_or_equal_to: 0)
  end
end

# ─── Minimum Viable Ledger (Sprint 4) ─────────────────────────────────────────

defmodule LRP.Ledger do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ledgers" do
    field :tenant_id,  :binary_id
    field :scheme,     :string # "VUK", "IFRS"
    field :is_leading, :boolean, default: false
    field :status,     :string, default: "active"

    timestamps()
  end

  def changeset(ledger, attrs) do
    ledger
    |> cast(attrs, [:tenant_id, :scheme, :is_leading, :status])
    |> validate_required([:tenant_id, :scheme])
    |> validate_inclusion(:scheme, ["VUK", "IFRS"])
    |> validate_inclusion(:status, ["active", "closed"])
  end
end

defmodule LRP.Journal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "journals" do
    field :tenant_id,       :binary_id
    field :ledger_id,       :binary_id
    field :doc_date,        :date
    field :posting_date,    :date
    field :source_event_id, :binary_id

    timestamps()
  end

  def changeset(journal, attrs) do
    journal
    |> cast(attrs, [:tenant_id, :ledger_id, :doc_date, :posting_date, :source_event_id])
    |> validate_required([:tenant_id, :ledger_id, :doc_date, :posting_date])
  end
end

defmodule LRP.JournalLine do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "journal_lines" do
    field :journal_id,  :binary_id
    field :account_id,  :string
    field :debit,       :decimal
    field :credit,      :decimal
    field :currency,    :string, default: "TRY"
    field :is_reversed, :boolean, default: false

    timestamps()
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [:journal_id, :account_id, :debit, :credit, :currency, :is_reversed])
    |> validate_required([:journal_id, :account_id, :debit, :credit])
    |> validate_number(:debit, greater_than_or_equal_to: 0.0)
    |> validate_number(:credit, greater_than_or_equal_to: 0.0)
  end
end

defmodule LRP.FiscalPeriod do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "fiscal_periods" do
    field :tenant_id,    :binary_id
    field :ledger_id,    :binary_id
    field :period_start, :date
    field :period_end,   :date
    field :status,       :string, default: "open" # "open", "closed"

    timestamps()
  end

  def changeset(period, attrs) do
    period
    |> cast(attrs, [:tenant_id, :ledger_id, :period_start, :period_end, :status])
    |> validate_required([:tenant_id, :ledger_id, :period_start, :period_end])
    |> validate_inclusion(:status, ["open", "closed"])
  end
end

# ─── Connector & EventSubscription (Sprint 5+ / ADR-0007) ─────────────────────

defmodule LRP.Connector do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "connectors" do
    field :tenant_id,   :binary_id
    field :type,        :string
    field :config,      :map, default: %{}
    field :auth_method, :string
    field :status,      :string, default: "active"

    timestamps()
  end

  def changeset(connector, attrs) do
    connector
    |> cast(attrs, [:tenant_id, :type, :config, :auth_method, :status])
    |> validate_required([:tenant_id, :type, :config, :auth_method])
    |> validate_inclusion(:status, ["active", "paused", "error", "deprecated"])
  end
end

defmodule LRP.EventSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "event_subscriptions" do
    field :tenant_id,           :binary_id
    field :actor_id,            :binary_id
    field :event_type_pattern,  :string
    field :webhook_url,         :string
    field :secret,              :string
    field :max_causation_depth, :integer, default: 3
    field :status,              :string, default: "active"

    timestamps()
  end

  def changeset(sub, attrs) do
    sub
    |> cast(attrs, [:tenant_id, :actor_id, :event_type_pattern, :webhook_url,
                    :secret, :max_causation_depth, :status])
    |> validate_required([:tenant_id, :event_type_pattern, :webhook_url])
    |> validate_inclusion(:status, ["active", "paused", "error"])
    |> validate_number(:max_causation_depth, greater_than_or_equal_to: 1)
  end
end


