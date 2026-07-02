defmodule LRP.Authorization do
  @moduledoc """
  ReBAC (Relation-based Access Control) Engine for LRP.
  Simulates a Zanzibar-like relationship evaluator using LRP's `Relationship` table.
  """

  import Ecto.Query
  alias LRP.Repo
  alias LRP.Relationship

  @doc """
  Verilen actor'ın, hedef nesne üzerinde belirtilen ilişkiye (relation) sahip olup olmadığını denetler.
  İlişki çözme kuralları:
  - `owner` yetkisi: Doğrudan (Actor, actor_id) -> "owner" -> (Object, object_id) ilişkisi olmalı.
  - `editor` yetkisi: Doğrudan "editor" veya "owner" ilişkisi olmalı.
  - `viewer` yetkisi:
    1. Doğrudan "viewer", "editor" veya "owner" ilişkisi varsa.
    2. Nesnenin üst klasörü/grubu varsa ve actor o klasör üzerinde "viewer" yetkisine sahipse.
    3. Actor bir grubun üyesiyse ve o grup nesne üzerinde "viewer" yetkisine sahipse.
  """
  def check_permission(actor_id, relation, object_id) do
    check_permission_recursive(actor_id, relation, object_id, MapSet.new())
  end

  defp check_permission_recursive(actor_id, relation, object_id, visited) do
    state_key = {actor_id, relation, object_id}

    if MapSet.member?(visited, state_key) do
      false
    else
      new_visited = MapSet.put(visited, state_key)
      
      cond do
        # 1. Doğrudan eşleşme kontrolü (Direct Relation)
        has_direct_relation?(actor_id, relation, object_id) ->
          true

        # 2. Üst yetki hiyerarşisi çözümü (Relation Implication)
        relation == "editor" and check_permission_recursive(actor_id, "owner", object_id, new_visited) ->
          true

        relation == "viewer" and (
          check_permission_recursive(actor_id, "editor", object_id, new_visited) or
          check_permission_recursive(actor_id, "owner", object_id, new_visited)
        ) ->
          true

        # 3. Transitive Klasör/Ebeveyn Yetki Çözümü (Nested Objects)
        # Örn: (Object, parent_id) -> "parent" -> (Object, object_id)
        # Eğer actor, parent_id üzerinde bu yetkiye sahipse, nesne üzerinde de sahiptir.
        has_parent_permission?(actor_id, relation, object_id, new_visited) ->
          true

        # 4. Transitive Grup/Cari Üyelik Yetki Çözümü (Nested Users / Subjects)
        # Örn: (Actor, actor_id) -> "member" -> (Object, group_id)
        # Eğer group_id, nesne üzerinde bu yetkiye sahipse, actor de sahiptir.
        has_group_permission?(actor_id, relation, object_id, new_visited) ->
          true

        true ->
          false
      end
    end
  end

  # Doğrudan veritabanı ilişkisi var mı kontrol eder
  defp has_direct_relation?(from_id, relation, to_id) do
    query =
      from(r in Relationship,
        where: r.from_id == ^from_id and
               r.to_id == ^to_id and
               r.relationship_type == ^to_string(relation)
      )
    Repo.exists?(query)
  end

  # Nesnenin ebeveyni üzerinden yetki devralmayı kontrol eder
  defp has_parent_permission?(actor_id, relation, object_id, visited) do
    # Nesnenin ebeveynlerini bul
    parents_query =
      from(r in Relationship,
        where: r.to_id == ^object_id and
               r.relationship_type == "parent",
        select: r.from_id
      )
    parent_ids = Repo.all(parents_query)

    Enum.any?(parent_ids, fn parent_id ->
      check_permission_recursive(actor_id, relation, parent_id, visited)
    end)
  end

  # Grup/Cari üyeliği üzerinden yetki devralmayı kontrol eder
  defp has_group_permission?(actor_id, relation, object_id, visited) do
    # Actor'ın üye olduğu grupları bul
    groups_query =
      from(r in Relationship,
        where: r.from_id == ^actor_id and
               r.relationship_type == "member",
        select: r.to_id
      )
    group_ids = Repo.all(groups_query)

    Enum.any?(group_ids, fn group_id ->
      # Grubun bu nesne üzerinde yetkisi var mı diye kontrol et
      # Burada subject artık actor_id değil group_id'dir
      check_permission_recursive(group_id, relation, object_id, visited)
    end)
  end
end
