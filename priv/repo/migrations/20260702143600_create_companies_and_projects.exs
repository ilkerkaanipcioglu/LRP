defmodule LRP.Repo.Migrations.CreateCompaniesAndProjects do
     use Ecto.Migration

     def change do
       create table(:companies, primary_key: false) do
         add :id, :binary_id, primary_key: true
         add :name, :string, null: false
         add :metadata, :map, default: "{}"
         timestamps()
       end

       create table(:projects, primary_key: false) do
         add :id, :binary_id, primary_key: true
         add :company_id, references(:companies, type: :binary_id, on_delete: :delete_all), null: false
         add :name, :string, null: false
         add :database_url, :string, null: false
         add :metadata, :map, default: "{}"
         timestamps()
       end

       alter table(:tenants) do
         add :project_id, references(:projects, type: :binary_id, on_delete: :nilify_all)
       end
     end
   end
