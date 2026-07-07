defmodule LRPWeb.AgentsLive.Index do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)
    agents =
      if tenant, do: LRP.list_agents_by_tenant(tenant.id), else: []

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:agents, agents)
     |> assign(:page_title, "Agents")
     |> assign(:active_nav, "bot")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <h1 class="page-title">Agent Hub</h1>
        <p class="page-subtitle">Manage and monitor AI agents</p>
      </div>
    </div>

    <%= if @tenant == nil do %>
      <div class="empty-state">
        <div class="empty-icon">🤖</div>
        <h3>Tenant bulunamadi</h3>
        <p><code>mix lrp.seed</code> calistirarak demo verisi yukleyin.</p>
      </div>
    <% else %>
      <%= if @agents == [] do %>
        <div class="empty-state">
          <div class="empty-icon">🤖</div>
          <h3>No agents yet</h3>
          <p>Agents will appear here once configured.</p>
        </div>
      <% else %>
        <div class="agents-grid">
          <%= for agent <- @agents do %>
            <.live_component
              module={LRPWeb.Components.AgentCard}
              id={agent.id}
              agent={agent}
              tenant_id={@tenant.id}
            />
          <% end %>
        </div>
      <% end %>
    <% end %>
    """
  end
end

defmodule LRPWeb.AgentsLive.Show do
  use LRPWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    agent = LRP.get_actor(id)
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)
    contexts =
      if agent && tenant do
        LRP.list_agent_contexts_by_tenant(tenant.id)
        |> Enum.filter(fn c -> c.actor_id == id end)
      else
        []
      end

    {:ok,
     socket
     |> assign(:agent, agent)
     |> assign(:contexts, contexts)
     |> assign(:page_title, if(agent, do: agent.name, else: "Agent Not Found"))
     |> assign(:active_nav, "bot")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <a href="/agents" class="back-link">← Agents</a>
    </div>

    <%= if @agent do %>
      <div class="agent-detail">
        <div class="agent-detail-header">
          <div class="agent-avatar-large">🤖</div>
          <div>
            <h2 class="agent-detail-name"><%= @agent.name %></h2>
            <div class="agent-detail-meta">
              <span class="badge"><%= @agent.type %></span>
              <span class={"agent-status #{@agent.status}"}><%= @agent.status %></span>
            </div>
          </div>
        </div>

        <div class="card" style="margin-top: 24px;">
          <div class="card-header">
            <span>Decision Log (AgentContext)</span>
            <span class="badge"><%= length(@contexts) %></span>
          </div>
          <%= if @contexts == [] do %>
            <div class="card-empty">
              <p class="thread-empty">No decision logs recorded yet.</p>
            </div>
          <% else %>
            <div class="context-list">
              <%= for ctx <- @contexts do %>
                <div class="context-item">
                  <div class="context-header">
                    <span class="context-action"><%= ctx.action %></span>
                    <span class="context-confidence">
                      Confidence: <%= format_confidence(ctx.confidence_score) %>
                    </span>
                  </div>
                  <div class="context-reasoning">
                    <%= ctx.reasoning_trace || "(no trace)" %>
                  </div>
                  <div class="context-meta">
                    <span><%= ctx.model_version || "N/A" %></span>
                    <span><%= format_dt(ctx.inserted_at) %></span>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="empty-state">
        <div class="empty-icon">🤖</div>
        <h3>Agent not found</h3>
      </div>
    <% end %>
    """
  end

  defp format_confidence(nil), do: "human"
  defp format_confidence(score) when is_float(score), do: Float.round(score, 2) |> to_string()

  defp format_dt(nil), do: ""
  defp format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %H:%M")
end
