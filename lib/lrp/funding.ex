defmodule LRP.Funding do
  @moduledoc """
  Community Funding domain logic.
  Manages token campaigns represented as generic objects and handles investor payouts.
  """

  alias LRP.Object

  @doc """
  Creates a new Funding Project object.
  """
  def create_funding_project(tenant_id, creator_id, name, requested_amount, payback_pct) do
    metadata = %{
      "creator_id" => creator_id,
      "requested_amount" => requested_amount,
      "current_funded" => 0,
      "payback_pct" => payback_pct,
      "status" => "funding",
      "total_returned" => 0
    }

    case LRP.create_object(%{
           tenant_id: tenant_id,
           type: "FundingProject",
           name: name,
           metadata: metadata
         }) do
      {:ok, project} ->
        # Link Creator Profile to this FundingProject
        LRP.relate("Object", creator_id, "Object", project.id, "creator_of")
        {:ok, project}

      error ->
        error
    end
  end

  @doc """
  Registers an investment by an investor in a project.
  Creates:
    - An LRP.Item under the project to track investment amount.
    - A Relationship connecting investor actor to the project object.
  Updates the campaign's current_funded amount.
  """
  def invest_in_project(_tenant_id, investor_id, project_id, amount) when is_integer(amount) and amount > 0 do
    case LRP.get_object(project_id) do
      nil ->
        {:error, :project_not_found}

      project ->
        # 1. Create investment Item
        item_attrs = %{
          object_id: project_id,
          name: "Investment by #{investor_id}",
          quantity: 1,
          unit_value: amount,
          currency: "TRY",
          metadata: %{"investor_id" => investor_id}
        }

        with {:ok, _item} <- LRP.create_item(item_attrs),
             {:ok, _rel} <- LRP.relate("Actor", investor_id, "Object", project_id, "invested_in") do
          
          # 2. Update project funded amount
          current_funded = Map.get(project.metadata, "current_funded", 0) + amount
          requested_amount = Map.get(project.metadata, "requested_amount", 0)

          status =
            if current_funded >= requested_amount do
              "funded"
            else
              "funding"
            end

          updated_metadata =
            project.metadata
            |> Map.put("current_funded", current_funded)
            |> Map.put("status", status)

          LRP.update_object(project, %{metadata: updated_metadata})
        end
    end
  end

  @doc """
  Distributes revenue to investors proportionally.
  Posts a double-entry Journal entry:
    - Debits: Creator's revenue/expense account
    - Credits: Investor accounts (split proportionally based on their share)
  """
  def distribute_project_revenue(tenant_id, project_id, revenue_amount, ledger_id, source_event_id \\ nil) do
    case LRP.get_object_with_items(project_id) do
      nil ->
        {:error, :project_not_found}

      project ->
        creator_id = Map.get(project.metadata, "creator_id")
        payback_pct = Map.get(project.metadata, "payback_pct", 0)
        
        # Payback pool: e.g. 15% of the total revenue
        payback_amount = revenue_amount * (payback_pct / 100.0)

        # Get investments
        investments = Enum.filter(project.items, fn item -> 
          Map.has_key?(item.metadata, "investor_id")
        end)

        total_funded = investments |> Enum.map(& &1.unit_value) |> Enum.sum()

        if total_funded <= 0 do
          {:error, :no_investments_found}
        else
          # Generate Journal lines
          # 1. Debit creator account
          creator_account = "760.CREATOR_#{creator_id}"
          
          investor_lines =
            Enum.map(investments, fn item ->
              investor_id = Map.get(item.metadata, "investor_id")
              share = item.unit_value / total_funded
              investor_payback = payback_amount * share

              %{
                account_id: "331.INVESTOR_#{investor_id}",
                debit: 0.0,
                credit: Float.round(investor_payback, 2),
                currency: "TRY"
              }
            end)

          # Combine debit and credits
          journal_lines = [
            %{
              account_id: creator_account,
              debit: Float.round(payback_amount, 2),
              credit: 0.0,
              currency: "TRY"
            }
            | investor_lines
          ]

          journal_attrs = %{
            doc_date: Date.utc_today(),
            posting_date: Date.utc_today(),
            source_event_id: source_event_id
          }

          # Post to Ledger
          case LRP.post_journal(tenant_id, ledger_id, journal_attrs, journal_lines) do
            {:ok, _result} ->
              # Update project metadata
              total_returned = Map.get(project.metadata, "total_returned", 0) + payback_amount
              updated_project_metadata = Map.put(project.metadata, "total_returned", total_returned)
              LRP.update_object(project, %{metadata: updated_project_metadata})

              # Update creator profile if available
              if creator = LRP.get_object(creator_id) do
                creator_returned = Map.get(creator.metadata, "total_returned", 0) + payback_amount
                
                # Update total funded on first distribution or investment
                creator_metadata =
                  creator.metadata
                  |> Map.put("total_returned", Float.round(creator_returned, 2))

                LRP.update_object(creator, %{metadata: creator_metadata})
              end

              {:ok, payback_amount}

            error ->
              error
          end
        end
    end
  end
end
