defmodule LRP.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "projects" do
    field :name, :string
    field :database_url, :string
    field :metadata, :map, default: %{}
    belongs_to :company, LRP.Company, type: :binary_id
    has_many :tenants, LRP.Tenant

    timestamps()
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [:company_id, :name, :database_url, :metadata])
    |> validate_required([:company_id, :name, :database_url])
  end
end
