defmodule LRPWeb.AdminLive.Index do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)
    subscriptions =
      if tenant, do: LRP.list_subscriptions(tenant.id), else: []

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:subscriptions, subscriptions)
     |> assign(:page_title, "Admin")
     |> assign(:active_nav, "admin")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <h1 class="page-title">Admin Panel</h1>
        <p class="page-subtitle">System configuration and connectors</p>
      </div>
    </div>

    <%= if @tenant == nil do %>
      <div class="empty-state">
        <div class="empty-icon">⚙️</div>
        <h3>Tenant bulunamadi</h3>
        <p><code>mix lrp.seed</code> calistirarak demo verisi yukleyin.</p>
      </div>
    <% else %>
      <div class="admin-sections">
        <div class="card">
          <div class="card-header">
            <span>Event Subscriptions (Webhooks)</span>
            <span class="badge"><%= length(@subscriptions) %></span>
          </div>
          <%= if @subscriptions == [] do %>
            <div class="card-empty">
              <div class="empty-icon">🔌</div>
              <h3>No connectors configured</h3>
              <p>Event subscriptions will appear here when configured.</p>
            </div>
          <% else %>
            <div class="connector-list">
              <%= for sub <- @subscriptions do %>
                <div class="connector-item">
                  <div class="connector-info">
                    <div class="connector-pattern"><%= sub.event_type_pattern %></div>
                    <div class="connector-url"><%= sub.webhook_url %></div>
                    <div class="connector-meta">
                      <span class={"connector-status status--#{sub.status}"}><%= sub.status %></span>
                      <span>Max depth: <%= sub.max_causation_depth %></span>
                    </div>
                  </div>
                  <div class="connector-time"><%= format_dt(sub.inserted_at) %></div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="card" style="margin-top: 24px;">
          <div class="card-header">
            <span>Tenant Info</span>
          </div>
          <div class="tenant-info">
            <div class="info-row">
              <span class="info-label">Tenant</span>
              <span class="info-value"><%= @tenant.name %></span>
            </div>
            <div class="info-row">
              <span class="info-label">ID</span>
              <span class="info-value mono"><%= @tenant.id %></span>
            </div>
            <div class="info-row">
              <span class="info-label">Status</span>
              <span class="info-value"><%= @tenant.status %></span>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_dt(nil), do: ""
  defp format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
end
