defmodule LRPWeb.ApprovalsLive.Index do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)
    approvals = if tenant, do: LRP.list_pending_approvals(tenant.id), else: []

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:approvals, approvals)
     |> assign(:page_title, "Approvals")
     |> assign(:active_nav, "mail")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <h1 class="page-title">Pending Approvals</h1>
        <p class="page-subtitle">Tasks waiting for your review</p>
      </div>
    </div>

    <%= if @tenant == nil do %>
      <div class="empty-state">
        <div class="empty-icon">📋</div>
        <h3>Tenant bulunamadi</h3>
        <p><code>mix lrp.seed</code> calistirarak demo verisi yukleyin.</p>
      </div>
    <% else %>
      <div class="card">
        <div class="card-header">
          <span>Pending Tasks</span>
          <span class="badge"><%= length(@approvals) %></span>
        </div>
        <%= if @approvals == [] do %>
          <div class="card-empty">
            <div class="empty-icon">✅</div>
            <h3>All caught up!</h3>
            <p>No pending approvals at this time.</p>
          </div>
        <% else %>
          <div class="approval-list">
            <%= for task <- @approvals do %>
              <div class="approval-item">
                <div class="approval-info">
                  <div class="approval-name"><%= task.name %></div>
                  <div class="approval-meta">
                    <span class="approval-process"><%= task.process_name %></span>
                    <span class={"approval-priority priority--#{task.priority}"}><%= task.priority %></span>
                  </div>
                </div>
                <div class="approval-time">
                  <%= format_datetime(task.inserted_at) %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp format_datetime(nil), do: ""
  defp format_datetime(dt) do
    Calendar.strftime(dt, "%d %b %H:%M")
  end
end
