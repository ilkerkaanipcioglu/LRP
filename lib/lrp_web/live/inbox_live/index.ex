defmodule LRPWeb.InboxLive.Index do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)
    emails = if tenant, do: LRP.list_email_documents(tenant.id), else: []

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:emails, emails)
     |> assign(:page_title, "Inbox")
     |> assign(:active_nav, "mail")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <h1 class="page-title">Inbox</h1>
        <p class="page-subtitle">E-posta, onaylar ve bildirimler</p>
      </div>
    </div>

    <%= if @tenant == nil do %>
      <div class="empty-state">
        <div class="empty-icon">📭</div>
        <h3>Tenant bulunamadi</h3>
        <p><code>mix lrp.seed</code> calistirarak demo verisi yukleyin.</p>
      </div>
    <% else %>
      <div class="card">
        <div class="card-header">
          <span>E-postalar</span>
          <span class="badge"><%= length(@emails) %></span>
        </div>
        <%= if @emails == [] do %>
          <div class="card-empty">
            <div class="empty-icon">📭</div>
            <h3>Henuz e-posta yok</h3>
            <p>
              <code>mix lrp.demo</code> calistirarak ornek e-posta
              akisini gorebilirsiniz.
            </p>
          </div>
        <% else %>
          <div class="email-list">
            <%= for email <- @emails do %>
              <div class="email-item">
                <div class="email-avatar">
                  <%= String.first(email.metadata["from"] || "?") %>
                </div>
                <div class="email-body">
                  <div class="email-from"><%= email.metadata["from"] || "Bilinmeyen" %></div>
                  <div class="email-subject"><%= email.name %></div>
                </div>
                <div class="email-meta">
                  <span class="email-date"><%= format_date(email.metadata["received_at"]) %></span>
                  <span class="email-status-dot"></span>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp format_date(nil), do: ""
  defp format_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, dt, _} ->
        Calendar.strftime(dt, "%d %b %H:%M")

      _ ->
        date_string
    end
  end
end
