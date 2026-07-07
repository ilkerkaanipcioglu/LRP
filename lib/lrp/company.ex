defmodule LRP.Company do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "companies" do
    field :name, :string
    field :metadata, :map, default: %{}
    has_many :projects, LRP.Project

    timestamps()
  end

  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :metadata])
    |> validate_required([:name])
  end
end
