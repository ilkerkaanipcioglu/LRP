defmodule LRP.OnboardingTest do
  use ExUnit.Case, async: true

  alias LRP.{Tenant, Actor, Event, ObservationMode, MaturityScore}
  alias LRP.Onboarding

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Onboarding Test A.Ş."})
    {:ok, employee} = LRP.create_actor(%{tenant_id: tenant.id, type: "User", name: "İlker"})
    {:ok, tenant: tenant, employee: employee}
  end

  test "start_wizard: yeni sistem kurulum senaryosu", %{tenant: tenant} do
    attrs = %{
      tenant_id: tenant.id,
      system_type: "new_system",
      output_mode: "elixir",
      connector: "none"
    }

    assert {:ok, result} = Onboarding.start_wizard(attrs)
    assert result.system_type == "new_system"
    assert result.output_mode == "elixir"
    assert is_binary(result.message)
  end

  test "start_wizard: mevcut sistem geçiş senaryosu (ObservationMode ve MaturityScore)", %{tenant: tenant} do
    attrs = %{
      tenant_id: tenant.id,
      system_type: "existing_system",
      output_mode: "md-only",
      connector: "email",
      target_system: "SAP ECC"
    }

    assert {:ok, result} = Onboarding.start_wizard(attrs)
    assert result.system_type == "existing_system"
    assert result.output_mode == "md-only"
    assert %ObservationMode{} = obs = result.observation_mode
    assert obs.tenant_id == tenant.id
    assert obs.target_system == "SAP ECC"
    assert obs.status == "active"
  end

  test "start_wizard: geçersiz parametre doğrulamaları", %{tenant: tenant} do
    # Eksik tenant_id
    assert {:error, "tenant_id zorunlu"} = Onboarding.start_wizard(%{system_type: "new_system"})

    # Geçersiz system_type
    assert {:error, "system_type: 'new_system' veya 'existing_system' olmalı"} =
             Onboarding.start_wizard(%{tenant_id: tenant.id, system_type: "invalid_type"})

    # Geçersiz output_mode
    assert {:error, "output_mode: 'elixir' veya 'md-only' olmalı (v1)"} =
             Onboarding.start_wizard(%{tenant_id: tenant.id, system_type: "new_system", output_mode: "rust"})
  end

  test "observe_existing, compute_maturity ve status akışı", %{tenant: tenant} do
    # 1. ObservationMode Oluştur
    assert {:ok, obs} = Onboarding.observe_existing(tenant.id, target_system: "Legacy Sales", scope: "specific_process")
    assert obs.scope == "specific_process"
    assert obs.status == "active"

    # 2. Event Ekle (Maturity Score hesaplamasına dahil olması için)
    {:ok, _event} = LRP.log_event(%{
      tenant_id: tenant.id,
      event_type: "sale_completed",
      source: "Legacy Sales",
      actor_confidence: 0.95,
      idempotency_key: "sale:101",
      payload: %{}
    })

    # 3. Maturity Score Hesapla
    assert {:ok, %MaturityScore{} = ms} = Onboarding.compute_maturity(obs.id)
    assert ms.observation_mode_id == obs.id
    assert ms.coverage_pct > 0.0
    assert ms.confidence_avg == 0.95
    assert ms.score > 0.0

    # 4. Status sorgula
    assert {:ok, status} = Onboarding.status(tenant.id)
    assert status.observation_mode.id == obs.id
    assert status.latest_score.id == ms.id
  end

  test "request_activation: gözlem modunu kapatır ve aktivasyon eventi üretir", %{tenant: tenant, employee: employee} do
    assert {:ok, obs} = Onboarding.observe_existing(tenant.id, target_system: "Legacy CRM")
    
    assert {:ok, result} = Onboarding.request_activation(obs.id, employee.id)
    assert result.status == "activated"
    assert result.observation_mode.status == "completed"

    # Event oluştu mu kontrol et
    events = LRP.list_events_by_tenant(tenant.id)
    activation_event = Enum.find(events, &(&1.event_type == "lrp_activated"))
    assert activation_event != nil
    assert activation_event.payload["observation_mode_id"] == obs.id
    assert activation_event.payload["activated_by"] == employee.id
  end
end
