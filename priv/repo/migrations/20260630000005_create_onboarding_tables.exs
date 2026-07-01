defmodule LRP.Repo.Migrations.CreateOnboardingTables do
  use Ecto.Migration

  def change do
    # ── OBSERVATION_MODE ──────────────────────────────────────────────────────
    # Mevcut bir sistemi gölge modda izlemek için. Onboarding'in "mevcut sistem"
    # seçeneği seçildiğinde oluşturulur.
    create table(:observation_modes, primary_key: false) do
      add :id,            :binary_id, primary_key: true
      add :tenant_id,     references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :scope,         :string, null: false  # full_system | specific_process
      add :target_system, :string               # "SAP ECC", "Gmail", "custom"
      add :purpose,       :string, null: false  # documentation_only | pre_migration | continuous_shadow
      add :status,        :string, null: false, default: "active"  # active | paused | completed
      add :metadata,      :map, default: %{}

      timestamps()
    end

    create index(:observation_modes, [:tenant_id])
    create index(:observation_modes, [:status])

    # ── MATURITY_SCORE ────────────────────────────────────────────────────────
    # LRP'nin "devreye hazır mı?" ölçümü. Kullanıcı bu skoru görerek
    # devreye alma kararını kendisi verir — otomatik tetikleme yoktur.
    create table(:maturity_scores, primary_key: false) do
      add :id,                 :binary_id, primary_key: true
      add :tenant_id,          references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :observation_mode_id, references(:observation_modes, type: :binary_id, on_delete: :delete_all), null: false

      add :score,          :float, null: false, default: 0.0  # 0.0 – 1.0
      add :coverage_pct,   :float, default: 0.0               # EVENT'lerin yüzde kaçı yakalanıyor
      add :confidence_avg, :float, default: 0.0               # ajan confidence ortalaması
      add :days_observed,  :integer, default: 0
      # Bilgi amaçlı öneri; otomatik devreye alma yapmaz.
      # nil | "ready_to_activate" | "activate_partial"
      add :recommendation, :string
      add :snapshot,       :map, default: %{}                 # hesaplama anındaki ham veri

      timestamps()
    end

    create index(:maturity_scores, [:tenant_id])
    create index(:maturity_scores, [:observation_mode_id])
  end
end
