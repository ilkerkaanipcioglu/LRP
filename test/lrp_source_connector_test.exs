defmodule LRP.SourceConnectorTest do
  use ExUnit.Case, async: false  # Gerçek GitHub API çağrısı — async: false

  @moduletag :integration  # mix test --only integration ile çalıştır

  # Gerçek LRP reposu — public, token gerektirmez
  @lrp_repo_url "https://github.com/ilkerkaanipcioglu/LRP"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Source Connector Test Tenant"})
    {:ok, tenant: tenant}
  end

  @tag timeout: 30_000
  test "LRP reposunu kendine bağlar ve entity'leri keşfeder", %{tenant: tenant} do
    IO.puts("\n[SourceConnector] LRP reposuna bağlanıyor: #{@lrp_repo_url}")

    result = LRP.SourceConnector.connect(tenant.id,
      repo_url: @lrp_repo_url,
      label: "LRP Self-Connect"
    )

    assert {:ok, %{source_system: source_system, entities: entities, event: event, stats: stats}} = result

    # SourceSystem OBJECT doğru oluştu
    assert source_system.type == "SourceSystem"
    assert source_system.name == "LRP Self-Connect"
    assert source_system.metadata["owner"] == "ilkerkaanipcioglu"
    assert source_system.metadata["repo"] == "LRP"
    assert source_system.metadata["language"] == "Elixir"

    IO.puts("[SourceConnector] Bulunan entity sayısı: #{length(entities)}")

    # Event kaydedildi
    assert event.event_type == "source_connected"
    assert event.source == "github"
    assert event.tier == "DURABLE"
    assert event.payload["owner"] == "ilkerkaanipcioglu"

    # SourceSystem → Event RELATIONSHIP kuruldu
    rels = LRP.list_relationships("Event", event.id, "triggered")
    assert length(rels) == 1
    assert hd(rels).to_id == source_system.id

    # Entity'ler keşfedildi (LRP'nin kendi migration'larından)
    assert length(entities) > 0
    entity_names = Enum.map(entities, & &1.name)
    IO.puts("[SourceConnector] Keşfedilen entity'ler: #{Enum.join(entity_names, ", ")}")

    # EntityType → SourceSystem RELATIONSHIP'leri kuruldu
    source_rels = LRP.list_relationships("SourceSystem", source_system.id, "contains")
    assert length(source_rels) == length(entities)

    # Stats kontrolü
    assert stats.files_scanned > 0
    assert stats.entities_found == length(entities)

    IO.puts("[SourceConnector] ✅ #{stats.files_scanned} dosya tarandı, #{stats.entities_found} entity keşfedildi")
  end

  @tag timeout: 60_000
  test "aynı repo aynı gün tekrar bağlanınca event idempotent kalır", %{tenant: tenant} do
    {:ok, first} = LRP.SourceConnector.connect(tenant.id, repo_url: @lrp_repo_url)

    # Aynı tenant, aynı gün → idempotency_key çakışır → on_conflict: :nothing
    # Yeni SourceSystem oluşur ama mevcut event tekrar kullanılır
    {:ok, second} = LRP.SourceConnector.connect(tenant.id, repo_url: @lrp_repo_url)

    # Her bağlantı için ayrı SourceSystem oluşur
    assert first.source_system.id != second.source_system.id

    # Ama event aynı idempotency_key üzerinden çalışır
    assert first.event.idempotency_key == second.event.idempotency_key

    IO.puts("[SourceConnector] ✅ Aynı event idempotent korundu: #{first.event.idempotency_key}")
  end


  @tag timeout: 10_000
  test "geçersiz repo URL'si hata döner", %{tenant: tenant} do
    result = LRP.SourceConnector.connect(tenant.id, repo_url: "https://github.com/nobody/nonexistent-repo-xyz-123")
    assert {:error, reason} = result
    assert is_binary(reason)
    IO.puts("[SourceConnector] Beklenen hata: #{reason}")
  end
end
