defmodule LRP.Creator do
  @moduledoc """
  Creator Profile domain logic.
  Stores and manages creator data inside generic LRP.Object (type: "Party") metadata.
  """

  alias LRP.Object

  @valid_creator_types ~w(kobi content music film game writer)

  @doc """
  Creates a new Creator Profile object as a generic Party.
  """
  def create_creator_profile(tenant_id, name, creator_type, extra_metadata \\ %{}) do
    if creator_type not in @valid_creator_types do
      {:error, :invalid_creator_type}
    else
      metadata =
        %{
          "creator_type" => creator_type,
          "platform_connections" => [],
          "trust_score" => 0.5,
          "total_funded" => 0,
          "total_returned" => 0,
          "production_history" => []
        }
        |> Map.merge(extra_metadata)

      LRP.create_object(%{
        tenant_id: tenant_id,
        type: "Party",
        name: name,
        metadata: metadata
      })
    end
  end

  @doc """
  Adds a platform connection (e.g. YouTube Studio, Spotify) to the creator profile
  and recalculates the trust score.
  """
  def add_platform_connection(%Object{type: "Party"} = creator, connection) when is_map(connection) do
    connections = Map.get(creator.metadata, "platform_connections", [])
    updated_connections = [connection | connections]

    updated_metadata =
      creator.metadata
      |> Map.put("platform_connections", updated_connections)

    # Temporary update to calculate trust score properly
    temp_creator = %{creator | metadata: updated_metadata}
    trust_score = calculate_trust_score(temp_creator)

    final_metadata = Map.put(updated_metadata, "trust_score", Float.round(trust_score, 2))

    LRP.update_object(creator, %{metadata: final_metadata})
  end

  @doc """
  Calculates the trust score of the creator profile (0.0 to 1.0).
  Formula:
    Base: 0.5
    Each platform connection: +0.10
    Each production history item: +0.05
    Cap: 1.0
  """
  def calculate_trust_score(%Object{type: "Party"} = creator) do
    connections = Map.get(creator.metadata, "platform_connections", [])
    history = Map.get(creator.metadata, "production_history", [])

    connections_count = length(connections)
    history_count = length(history)

    score = 0.5 + (connections_count * 0.10) + (history_count * 0.05)
    clamp(score, 0.0, 1.0)
  end

  defp clamp(val, min, max) do
    cond do
      val < min -> min
      val > max -> max
      true -> val
    end
  end
end
