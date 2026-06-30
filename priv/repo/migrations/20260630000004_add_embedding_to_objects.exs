defmodule LRP.Repo.Migrations.AddEmbeddingToObjects do
  use Ecto.Migration

  def change do
    # embedding — OBJECT tablosuna (Semantic/Vector Search)
    # Ajanların "bu nesneye benzer ne var?" sorgusunu semantik olarak çözmesi için.
    # PostgreSQL pgvector eklentisi ile vector(1536) tipinde tutulur.
    # SQLite adaptöründe :binary olarak saklanır (NULL bırakılabilir).
    alter table(:objects) do
      add :embedding, :binary    # PostgreSQL'de pgvector migration'ı ayrı migration ile yapılır
    end
  end
end
