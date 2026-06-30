defmodule LRP.Repo.Migrations.AddActorConfidenceAndIdempotency do
  use Ecto.Migration

  def change do
    # actor_confidence — EVENT tablosuna
    # NULL = insan eylemi, 0.0-1.0 = ajan eylemi
    # Düşük confidence değeri otomatik ApprovalRequest tetikler
    alter table(:events) do
      add :actor_confidence, :float         # nullable, sadece Agent actor'lar için
      add :idempotency_key, :string         # retry-safe: aynı event iki kez insert edilemez
    end

    create unique_index(:events, [:idempotency_key])

    # actor_confidence — VERSION tablosuna
    # Ajan tarafından commit edilen versiyonların güven skoru
    alter table(:versions) do
      add :actor_confidence, :float         # nullable, sadece Agent actor'lar için
    end
  end
end
