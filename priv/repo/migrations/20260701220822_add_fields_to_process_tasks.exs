defmodule LRP.Repo.Migrations.AddFieldsToProcessTasks do
  use Ecto.Migration

  def change do
    alter table(:process_tasks) do
      add :name, :string
      add :priority, :string, default: "medium"
      add :metadata, :map, null: false, default: "{}"
    end
  end
end
