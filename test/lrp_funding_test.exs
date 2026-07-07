defmodule LRP.FundingTest do
  use ExUnit.Case, async: true

  alias LRP.Creator
  alias LRP.Funding
  import Ecto.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(LRP.Repo)
    {:ok, tenant} = LRP.create_tenant(%{name: "Funding Test Tenant"})
    {:ok, ledger} = LRP.create_ledger(%{
      tenant_id: tenant.id,
      scheme: "VUK",
      is_leading: true,
      status: "active"
    })
    {:ok, _period} = LRP.create_fiscal_period(%{
      tenant_id: tenant.id,
      ledger_id: ledger.id,
      period_start: ~D[2026-07-01],
      period_end: ~D[2026-07-31],
      status: "open"
    })
    
    {:ok, tenant: tenant, ledger: ledger}
  end

  test "funding project workflow: create, invest, and distribute revenue", %{tenant: tenant, ledger: ledger} do
    # 1. Create Creator Profile
    {:ok, creator} = Creator.create_creator_profile(tenant.id, "Ahmet YouTuber", "content")
    
    # 2. Create Funding Project Campaign
    {:ok, project} = Funding.create_funding_project(tenant.id, creator.id, "6 Bölümlük Belgesel", 15000, 15)
    
    assert project.type == "FundingProject"
    assert Map.get(project.metadata, "requested_amount") == 15000
    assert Map.get(project.metadata, "current_funded") == 0
    assert Map.get(project.metadata, "status") == "funding"

    # 3. Create investor actors and invest
    {:ok, investor1} = LRP.create_actor(%{tenant_id: tenant.id, type: "User", name: "Investor 1"})
    {:ok, investor2} = LRP.create_actor(%{tenant_id: tenant.id, type: "User", name: "Investor 2"})

    # Invest 5,000 TL from investor 1
    {:ok, project} = Funding.invest_in_project(tenant.id, investor1.id, project.id, 5000)
    assert Map.get(project.metadata, "current_funded") == 5000
    assert Map.get(project.metadata, "status") == "funding"

    # Invest 10,000 TL from investor 2 (campaign should be fully funded)
    {:ok, project} = Funding.invest_in_project(tenant.id, investor2.id, project.id, 10000)
    assert Map.get(project.metadata, "current_funded") == 15000
    assert Map.get(project.metadata, "status") == "funded"

    # Verify investments are stored as items and relationships
    relationships = LRP.list_relationships("Actor", investor1.id, "invested_in")
    assert length(relationships) == 1
    assert Enum.at(relationships, 0).to_id == project.id

    # 4. Distribute project revenue (simulate receiving 10,000 TL revenue)
    # Total payback is 15% of 10,000 = 1,500 TL
    # Investor 1 (5k / 15k = 1/3 share) -> should get 500 TL
    # Investor 2 (10k / 15k = 2/3 share) -> should get 1000 TL
    assert {:ok, payback_amount} = Funding.distribute_project_revenue(tenant.id, project.id, 10000, ledger.id)
    assert payback_amount == 1500.0

    # Verify posted Journal and Lines in Double-Entry Ledger
    journals = LRP.Repo.all(LRP.Journal)
    assert length(journals) == 1
    journal = Enum.at(journals, 0)
    
    lines = LRP.Repo.all(from(l in LRP.JournalLine, where: l.journal_id == ^journal.id))
    assert length(lines) == 3

    # Check creator debit line
    creator_debit = Enum.find(lines, &(&1.account_id == "760.CREATOR_#{creator.id}"))
    assert Decimal.eq?(creator_debit.debit, Decimal.new("1500.00"))
    assert Decimal.eq?(creator_debit.credit, Decimal.new("0.00"))

    # Check investor credit lines
    inv1_credit = Enum.find(lines, &(&1.account_id == "331.INVESTOR_#{investor1.id}"))
    assert Decimal.eq?(inv1_credit.debit, Decimal.new("0.00"))
    assert Decimal.eq?(inv1_credit.credit, Decimal.new("500.00"))

    inv2_credit = Enum.find(lines, &(&1.account_id == "331.INVESTOR_#{investor2.id}"))
    assert Decimal.eq?(inv2_credit.debit, Decimal.new("0.00"))
    assert Decimal.eq?(inv2_credit.credit, Decimal.new("1000.00"))
  end
end
