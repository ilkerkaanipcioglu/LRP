defmodule LRP.Repo.Migrations.CreateMigrationTracker do
  use Ecto.Migration

  def change do
    # ── MIGRATION_TRACKER ─────────────────────────────────────────────────────
    # Geçişin kendisini izler: shadow → partial → primary → full_cutover
    # ADR-0005: discrepancy_count sıfıra düşmeden sonraki stage'e geçilemez.
    # full_cutover için kullanıcı onayı zorunludur — sistem asla otomatik geçmez.
    create table(:migration_trackers, primary_key: false) do
      add :id,               :binary_id, primary_key: true
      add :tenant_id,        references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :capability_id,    references(:capabilities, type: :binary_id, on_delete: :restrict), null: false
      add :from_provider_id, references(:providers, type: :binary_id, on_delete: :restrict), null: false
      add :to_provider_id,   references(:providers, type: :binary_id, on_delete: :restrict), null: false

      # Geçiş aşaması:
      # shadow      → yeni provider sadece izliyor, eski gerçek işi yapıyor
      # partial     → yeni provider bazı düşük riskli işlemleri yapıyor
      # primary     → yeni provider ana, eski yedek/doğrulama
      # full_cutover → eski deprecated, arşiv amaçlı
      add :stage,             :string, null: false, default: "shadow"

      add :coverage_pct,      :float, default: 0.0    # event'lerin kaçı yeni provider'da
      add :discrepancy_count, :integer, default: 0    # iki provider arasındaki uyuşmazlık
      add :started_at,        :utc_datetime, null: false
      add :target_cutover_at, :utc_datetime           # hedef tarih (zorunlu değil)
      add :completed_at,      :utc_datetime           # full_cutover tamamlandığında
      add :notes,             :string

      timestamps()
    end

    create index(:migration_trackers, [:tenant_id])
    create index(:migration_trackers, [:capability_id])
    create index(:migration_trackers, [:stage])
  end
end
