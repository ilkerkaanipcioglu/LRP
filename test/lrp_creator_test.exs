defmodule LRP.CreatorTest do
  use ExUnit.Case, async: true

  alias LRP.Creator

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Creator Test Tenant"})
    {:ok, tenant: tenant}
  end

  test "creator profile creation with default fields", %{tenant: tenant} do
    assert {:ok, creator} = Creator.create_creator_profile(tenant.id, "Ahmet", "writer")
    assert creator.type == "Party"
    assert creator.name == "Ahmet"
    assert Map.get(creator.metadata, "creator_type") == "writer"
    assert Map.get(creator.metadata, "trust_score") == 0.5
    assert Map.get(creator.metadata, "platform_connections") == []
    assert Map.get(creator.metadata, "total_funded") == 0
    assert Map.get(creator.metadata, "total_returned") == 0
  end

  test "invalid creator type returns error", %{tenant: tenant} do
    assert {:error, :invalid_creator_type} = Creator.create_creator_profile(tenant.id, "Invalid", "invalid_type")
  end

  test "add platform connections and recalculate trust score", %{tenant: tenant} do
    {:ok, creator} = Creator.create_creator_profile(tenant.id, "Müzisyen Y", "music")

    # Connect YouTube Studio
    {:ok, creator} = Creator.add_platform_connection(creator, %{
      "platform" => "youtube",
      "bonus" => 0.15,
      "details" => "YT channel verified"
    })
    
    assert Map.get(creator.metadata, "trust_score") == 0.60
    assert length(Map.get(creator.metadata, "platform_connections")) == 1

    # Connect Spotify
    {:ok, creator} = Creator.add_platform_connection(creator, %{
      "platform" => "spotify",
      "bonus" => 0.10,
      "details" => "Spotify profile verified"
    })
    
    assert Map.get(creator.metadata, "trust_score") == 0.70
    assert length(Map.get(creator.metadata, "platform_connections")) == 2
  end
end
