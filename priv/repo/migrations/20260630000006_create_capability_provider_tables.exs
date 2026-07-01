defmodule LRP.Repo.Migrations.CreateCapabilityProviderTables do
  use Ecto.Migration

  def change do
    # ── CAPABILITY ────────────────────────────────────────────────────────────
    # "Ne yapılıyor?" sözleşmesi. Provider değişse bile bu tanım değişmez.
    # ADR-0004: Hot-Swap Provider Pattern
    create table(:capabilities, primary_key: false) do
      add :id,                 :binary_id, primary_key: true
      add :tenant_id,          references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :capability_type,    :string, null: false  # email | slack | accounting | note_taking | ...
      # JSONB — zorunlu fonksiyon listesi; provider bu kontrata uymak zorunda
      add :interface_contract, :map, default: %{}
      add :status,             :string, null: false, default: "active"  # active | deprecated
      add :description,        :string

      timestamps()
    end

    create index(:capabilities, [:tenant_id])
    create index(:capabilities, [:capability_type])
    create unique_index(:capabilities, [:tenant_id, :capability_type])

    # ── PROVIDER ──────────────────────────────────────────────────────────────
    # "Kim/nasıl yapıyor?" — capability'yi gerçekte kimin yaptığını tanımlar.
    # provider_type dil-bağımsızdır; LRP provider'ın dilini umursamaz.
    create table(:providers, primary_key: false) do
      add :id,            :binary_id, primary_key: true
      add :tenant_id,     references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :capability_id, references(:capabilities, type: :binary_id, on_delete: :restrict), null: false

      # internal_md | external_app | elixir_module | agent | human
      add :provider_type, :string, null: false
      # JSONB — {path:, connector_id:, module:, webhook_url:, ...}
      add :provider_ref,  :map, default: %{}
      add :version,       :string
      add :status,        :string, null: false, default: "active"  # active | standby | deprecated
      add :description,   :string

      timestamps()
    end

    create index(:providers, [:tenant_id])
    create index(:providers, [:capability_id])
    create index(:providers, [:status])

    # ── PROVIDER_BINDING ──────────────────────────────────────────────────────
    # Hangi provider şu an aktif? Bu kayıt değişince hot-swap gerçekleşir.
    # Değişiklik her zaman VERSION kaydı oluşturur — "hangi tarihte kim/ne yapıyordu" denetim için kritik.
    create table(:provider_bindings, primary_key: false) do
      add :id,                 :binary_id, primary_key: true
      add :tenant_id,          references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :capability_id,      references(:capabilities, type: :binary_id, on_delete: :restrict), null: false
      add :active_provider_id, references(:providers, type: :binary_id, on_delete: :restrict), null: false
      add :bound_by_actor_id,  :binary_id  # kim bağladı (User veya Agent)
      add :bound_at,           :utc_datetime, null: false
      add :notes,              :string

      timestamps()
    end

    create index(:provider_bindings, [:tenant_id])
    create index(:provider_bindings, [:capability_id])
    # Bir tenant'ta bir capability için her an tek aktif binding olabilir
    create unique_index(:provider_bindings, [:tenant_id, :capability_id])
  end
end
