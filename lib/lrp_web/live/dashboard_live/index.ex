defmodule LRPWeb.DashboardLive.Index do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)
    counts = LRP.count_all()
    recent_events =
      if tenant, do: LRP.list_recent_events(tenant.id, 20), else: []

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:counts, counts)
     |> assign(:recent_events, recent_events)
     |> assign(:page_title, "Dashboard")
     |> assign(:active_nav, "dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <h1 class="page-title">System Dashboard</h1>
        <p class="page-subtitle">Real-time LRP platform overview</p>
      </div>
    </div>

    <%= if @tenant == nil do %>
      <div class="empty-state">
        <div class="empty-icon">📊</div>
        <h3>Tenant bulunamadi</h3>
        <p><code>mix lrp.seed</code> calistirarak demo verisi yukleyin.</p>
      </div>
    <% else %>
      <div class="dashboard-grid">
        <div class="stat-card">
          <div class="stat-value"><%= @counts.tenants %></div>
          <div class="stat-label">Tenants</div>
        </div>
        <div class="stat-card">
          <div class="stat-value"><%= @counts.actors %></div>
          <div class="stat-label">Actors</div>
        </div>
        <div class="stat-card">
          <div class="stat-value"><%= @counts.objects %></div>
          <div class="stat-label">Objects</div>
        </div>
        <div class="stat-card">
          <div class="stat-value"><%= @counts.events %></div>
          <div class="stat-label">Events</div>
        </div>
        <div class="stat-card">
          <div class="stat-value"><%= @counts.relationships %></div>
          <div class="stat-label">Relationships</div>
        </div>
        <div class="stat-card">
          <div class="stat-value"><%= @counts.process_tasks %></div>
          <div class="stat-label">Tasks</div>
        </div>
        <div class="stat-card">
          <div class="stat-value"><%= @counts.versions %></div>
          <div class="stat-label">Versions</div>
        </div>
        <div class="stat-card">
          <div class="stat-value"><%= @counts.agent_contexts %></div>
          <div class="stat-label">Agent Decisions</div>
        </div>
      </div>

      <div class="card" style="margin-top: 24px;">
        <div class="card-header">
          <span>Recent Events</span>
          <span class="badge"><%= length(@recent_events) %></span>
        </div>
        <%= if @recent_events == [] do %>
          <div class="card-empty">
            <p class="thread-empty">No events yet.</p>
          </div>
        <% else %>
          <div class="event-feed">
            <%= for event <- @recent_events do %>
              <div class="event-feed-item">
                <div class="event-feed-type"><%= event.event_type %></div>
                <div class="event-feed-source"><%= event.source %></div>
                <div class="event-feed-time"><%= format_dt(event.occurred_at) %></div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp format_dt(nil), do: ""
  defp format_dt(dt) when is_binary(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, d, _} -> Calendar.strftime(d, "%d %b %H:%M:%S")
      _ -> dt
    end
  end
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %H:%M:%S")
  defp format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %H:%M:%S")
end
