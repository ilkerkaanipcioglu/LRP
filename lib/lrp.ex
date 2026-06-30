defmodule LRP do
  @moduledoc """
  Core LRP (Lightweight Resource Planning) Engine API.
  Implements the Object Graph, Event Stream, Policies, and Git-like Versioning.
  """

  import Ecto.Query
  alias LRP.Repo
  alias LRP.{Tenant, Actor, Object, Item, Relationship, Event, Policy, ProcessTask, Version}

  # --- Tenant API ---
  def create_tenant(attrs) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  # --- Actor API ---
  def create_actor(attrs) do
    %Actor{}
    |> Actor.changeset(attrs)
    |> Repo.insert()
  end

  # --- Object API ---
  def create_object(attrs) do
    %Object{}
    |> Object.changeset(attrs)
    |> Repo.insert()
  end

  def get_object(id) do
    Repo.get(Object, id)
  end

  def get_object_with_items(id) do
    Object
    |> where(id: ^id)
    |> preload([:items])
    |> Repo.one()
  end

  def update_object(%Object{} = object, attrs) do
    object
    |> Object.changeset(attrs)
    |> Repo.update()
  end

  # --- Item API ---
  def create_item(attrs) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  # --- Relationships API ---
  def relate(from_entity, from_id, to_entity, to_id, relationship_type) do
    attrs = %{
      from_entity: to_string(from_entity),
      from_id: from_id,
      to_entity: to_string(to_entity),
      to_id: to_id,
      relationship_type: relationship_type,
      valid_from: DateTime.utc_now()
    }

    %Relationship{}
    |> Relationship.changeset(attrs)
    |> Repo.insert()
  end

  def list_relationships(from_entity, from_id, relationship_type \\ nil) do
    query = from(r in Relationship, where: r.from_entity == ^to_string(from_entity) and r.from_id == ^from_id)

    query =
      if relationship_type do
        from(r in query, where: r.relationship_type == ^relationship_type)
      else
        query
      end

    Repo.all(query)
  end

  # --- Events API ---
  def log_event(attrs) do
    attrs = Map.put_new(attrs, :occurred_at, DateTime.utc_now())

    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end

  # --- Git-like Versioning API ---
  def commit_version(object_id, committed_by_actor_id, commit_message) do
    # Fetch the object with its items to create a snapshot
    case get_object_with_items(object_id) do
      nil ->
        {:error, :object_not_found}

      object ->
        # Find latest version to set parent_version_id
        latest_version =
          Version
          |> where(object_id: ^object_id)
          |> order_by(desc: :committed_at)
          |> limit(1)
          |> Repo.one()

        parent_version_id = if latest_version, do: latest_version.id, else: nil

        # Generate object snapshot
        snapshot = %{
          "name" => object.name,
          "status" => object.status,
          "metadata" => object.metadata,
          "items" => Enum.map(object.items, fn item ->
            %{
              "name" => item.name,
              "quantity" => item.quantity,
              "unit_value" => item.unit_value,
              "currency" => item.currency,
              "status" => item.status,
              "metadata" => item.metadata
            }
          end)
        }

        attrs = %{
          object_id: object_id,
          parent_version_id: parent_version_id,
          commit_message: commit_message,
          committed_by_actor_id: committed_by_actor_id,
          committed_at: DateTime.utc_now(),
          object_snapshot: snapshot
        }

        %Version{}
        |> Version.changeset(attrs)
        |> Repo.insert()
    end
  end

  def get_version_history(object_id) do
    Version
    |> where(object_id: ^object_id)
    |> order_by([desc: :committed_at, desc: :inserted_at])
    |> Repo.all()
  end

  # --- Policy & Authorization API ---
  def create_policy(attrs) do
    %Policy{}
    |> Policy.changeset(attrs)
    |> Repo.insert()
  end

  def authorize(actor_id, resource_type, action) do
    # Deny by default. Check if there is an allow policy matching.
    # We support wildcards "*" for resource_type and action.
    query =
      from(p in Policy,
        where: p.actor_id == ^actor_id and
          (p.resource_type == ^resource_type or p.resource_type == "*") and
          (p.action == ^action or p.action == "*")
      )

    policies = Repo.all(query)

    # If there's any deny policy, it takes precedence. Otherwise allow if there's any allow policy.
    has_deny = Enum.any?(policies, fn p -> p.effect == "deny" end)
    has_allow = Enum.any?(policies, fn p -> p.effect == "allow" end)

    cond do
      has_deny -> :deny
      has_allow -> :allow
      true -> :deny # Default deny
    end
  end

  # --- Process & Task API ---
  def create_process_task(attrs) do
    %ProcessTask{}
    |> ProcessTask.changeset(attrs)
    |> Repo.insert()
  end

  def update_process_task(%ProcessTask{} = task, attrs) do
    task
    |> ProcessTask.changeset(attrs)
    |> Repo.update()
  end
end
