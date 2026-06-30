defmodule LRP.Repo.Migrations.CreateAgentContext do
  use Ecto.Migration

  def change do
    # AGENT_CONTEXT — Her ajan eyleminin "neden bu kararı verdi" denetim tablosu
    create table(:agent_contexts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:actors, type: :binary_id, on_delete: :delete_all), null: false
      add :object_id, references(:objects, type: :binary_id, on_delete: :nilify_all)
      add :event_id, references(:events, type: :binary_id, on_delete: :nilify_all)

      # Explainability alanları
      add :reasoning_trace, :text           # LLM'in düşünce zinciri
      add :confidence_score, :float         # 0.0-1.0, NULL=insan
      add :model_version, :string           # "gemini-2.0-flash", "claude-4" vb.
      add :prompt_hash, :string             # SHA256 hash of the prompt sent

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:agent_contexts, [:tenant_id])
    create index(:agent_contexts, [:actor_id])
    create index(:agent_contexts, [:object_id])
    create index(:agent_contexts, [:event_id])
  end
end
