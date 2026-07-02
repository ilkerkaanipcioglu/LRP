defmodule LRP.JSONPatch do
  @moduledoc """
  Lightweight RFC 6902 JSON Patch implementation in Elixir.
  Generates and applies delta patches for object snapshots.
  """

  @doc """
  Generates a list of RFC 6902 JSON Patches representing differences from `old` to `new`.
  """
  def diff(old, new) do
    do_diff(old, new, "")
  end

  defp do_diff(old, new, path) when is_map(old) and is_map(new) do
    # Keys in old but not in new (removed keys)
    removed =
      (Map.keys(old) -- Map.keys(new))
      |> Enum.map(fn key ->
        %{"op" => "remove", "path" => join_path(path, key)}
      end)

    # Keys in new but not in old (added keys)
    added =
      (Map.keys(new) -- Map.keys(old))
      |> Enum.map(fn key ->
        %{"op" => "add", "path" => join_path(path, key), "value" => Map.get(new, key)}
      end)

    # Keys in both (changed or nested maps)
    changed =
      (Map.keys(old) -- (Map.keys(old) -- Map.keys(new)))
      |> Enum.flat_map(fn key ->
        old_val = Map.get(old, key)
        new_val = Map.get(new, key)
        do_diff(old_val, new_val, join_path(path, key))
      end)

    removed ++ added ++ changed
  end

  # For lists: replace the whole list if they differ
  defp do_diff(old, new, path) when is_list(old) and is_list(new) do
    if old == new do
      []
    else
      [%{"op" => "replace", "path" => path, "value" => new}]
    end
  end

  # For primitives
  defp do_diff(old, new, path) do
    if old == new do
      []
    else
      [%{"op" => "replace", "path" => path, "value" => new}]
    end
  end

  defp join_path(parent_path, key) do
    "#{parent_path}/#{key}"
  end

  @doc """
  Applies a list of RFC 6902 JSON Patches to `old_map`.
  """
  def apply_patch(old_map, patches) do
    Enum.reduce(patches, old_map, fn patch, acc ->
      apply_single(acc, patch)
    end)
  end

  defp apply_single(acc, %{"op" => "add", "path" => path, "value" => val}) do
    put_in_path(acc, split_path(path), val)
  end

  defp apply_single(acc, %{"op" => "replace", "path" => path, "value" => val}) do
    put_in_path(acc, split_path(path), val)
  end

  defp apply_single(acc, %{"op" => "remove", "path" => path}) do
    delete_in_path(acc, split_path(path))
  end

  defp split_path(path) do
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
  end

  defp put_in_path(_map, [], val), do: val
  defp put_in_path(map, [key | rest], val) when is_map(map) do
    Map.put(map, key, put_in_path(Map.get(map, key, %{}), rest, val))
  end
  defp put_in_path(_map, _keys, val), do: val

  defp delete_in_path(map, []) do
    map
  end
  defp delete_in_path(map, [key]) when is_map(map) do
    Map.delete(map, key)
  end
  defp delete_in_path(map, [key | rest]) when is_map(map) do
    case Map.get(map, key) do
      nil -> map
      sub -> Map.put(map, key, delete_in_path(sub, rest))
    end
  end
  defp delete_in_path(map, _), do: map
end
