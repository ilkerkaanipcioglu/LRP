defmodule LRP.ReadObject do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "read_objects" do
    field :tenant_id, :binary_id
    field :type, :string
    field :name, :string
    field :status, :string
    field :metadata, :map, default: %{}
    field :parent_id, :binary_id
    
    # Flat reporting fields
    field :owner_name, :string
    field :item_count, :integer, default: 0
    field :total_value, :integer, default: 0

    timestamps()
  end

  def changeset(read_object, attrs) do
    read_object
    |> cast(attrs, [:id, :tenant_id, :type, :name, :status, :metadata, :parent_id, :owner_name, :item_count, :total_value])
    |> validate_required([:id, :tenant_id, :type, :name, :status])
  end
end

defmodule LRP.ReadModel do
  @moduledoc """
  CQRS Read Model Engine.
  Asynchronously flattens EAV Object Graph data into flat relational views.
  """

  import Ecto.Query
  alias LRP.Repo
  alias LRP.{Object, Relationship, ReadObject}

  @doc """
  Düzleştirilmiş read model üzerinden nesneleri listeler (CQRS Hızlı Okuma).
  """
  def list_objects(tenant_id, type \\ nil) do
    query = from(ro in ReadObject, where: ro.tenant_id == ^tenant_id)
    query = if type, do: from(ro in query, where: ro.type == ^type), else: query
    Repo.all(query)
  end

  @doc """
  Bir nesnenin tüm verilerini (Items ve Relationship sahipleri dahil) düzleştirerek
  `read_objects` tablosuna yazar veya günceller.
  """
  def sync_object(object_id) do
    # 1. Write-path üzerinden nesneyi ve item'larını anlık tutarlı (strongly consistent) oku
    case Repo.get(Object, object_id) |> Repo.preload([:items]) do
      nil ->
        # EAV'de silinmişse Read View'dan da sil
        case Repo.get(ReadObject, object_id) do
          nil -> :ok
          ro -> Repo.delete(ro)
        end
        {:ok, :deleted}

      object ->
        # 2. Ürün sayısı ve toplam fatura/stok değerini hesapla
        item_count = Enum.count(object.items)
        total_value = Enum.reduce(object.items, 0, fn item, acc ->
          acc + (item.quantity * item.unit_value)
        end)

        # 3. Grafik üzerinden ilişkili sahibi (owner) veya cari unvanını çöz
        owner_name = resolve_owner_name(object_id)

        # 4. Read model nesnesini güncelle veya ekle
        attrs = %{
          id: object.id,
          tenant_id: object.tenant_id,
          type: object.type,
          name: object.name,
          status: object.status,
          metadata: object.metadata,
          parent_id: object.parent_id,
          owner_name: owner_name,
          item_count: item_count,
          total_value: total_value
        }

        %ReadObject{}
        |> ReadObject.changeset(attrs)
        |> Repo.insert(on_conflict: :replace_all, conflict_target: :id)
    end
  end

  # Transitive olarak nesnenin sahibinin ismini çözümler
  defp resolve_owner_name(object_id) do
    # (Actor/Object, owner_id) -> "owner" -> (Object, object_id)
    query =
      from(r in Relationship,
        where: r.to_id == ^object_id and r.relationship_type == "owner",
        select: {r.from_entity, r.from_id}
      )

    case Repo.one(query) do
      {"Actor", actor_id} ->
        query_actor = from(a in LRP.Actor, where: a.id == ^actor_id, select: a.name)
        Repo.one(query_actor)

      {"Object", parent_obj_id} ->
        query_obj = from(o in Object, where: o.id == ^parent_obj_id, select: o.name)
        Repo.one(query_obj)

      _ ->
        nil
    end
  end

  @doc """
  Bir event gerçekleştiğinde asenkron olarak ilişkili nesnelerin read view'larını
  arka planda tetikler (Non-blocking eventual consistency).
  """
  def trigger_async_sync(object_id) do
    # BEAM process'i üzerinde asenkron çalıştırarak write-path'i geciktirmez (Eventual Consistency)
    Task.start(fn ->
      sync_object(object_id)
    end)
  end
end
