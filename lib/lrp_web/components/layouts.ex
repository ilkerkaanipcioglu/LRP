defmodule LRPWeb.Layouts do
  use LRPWeb, :html

  @nav_items [
    {"Inbox", "/inbox", "mail"},
    {"Workspace", "/workspace", "calendar"},
    {"Agents", "/agents", "bot"},
    {"Studio", "/studio", "film"},
    {"Uygulamalar", "/apps", "apps"}
  ]

  defp nav_icon("mail"), do: "📥"
  defp nav_icon("calendar"), do: "📅"
  defp nav_icon("bot"), do: "🤖"
  defp nav_icon("film"), do: "🎬"
  defp nav_icon("apps"), do: "📱"
  defp nav_icon("admin"), do: "⚙️"
  defp nav_icon(_), do: "📄"

  defp nav_path("mail"), do: ~p"/inbox"
  defp nav_path("calendar"), do: ~p"/workspace"
  defp nav_path("bot"), do: ~p"/agents"
  defp nav_path("film"), do: ~p"/studio"
  defp nav_path("apps"), do: ~p"/apps"
  defp nav_path("admin"), do: ~p"/admin"
  defp nav_path(_), do: "#"

  def nav_item(assigns) do
    ~H"""
    <a
      href={nav_path(@icon)}
      class={["nav-link", @active == @icon && "nav-link--active"]}
    >
      <span class="nav-icon"><%= nav_icon(@icon) %></span>
      <span class="nav-label"><%= @label %></span>
    </a>
    """
  end

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="tr">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <Phoenix.HTML.Tag.csrf_token() />
        <title><%= assigns[:page_title] || "LRP Platform" %> · LRP Platform</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Outfit:wght@500;600;700&display=swap" rel="stylesheet">
        <link rel="stylesheet" href={~p"/assets/css/app.css"}>
      </head>
      <body>
        <div id="phx-disconnected-banner" class="disconnected-banner">
          Bağlantı kesildi — yeniden bağlanıyor...
        </div>
        <%= @inner_content %>
      </body>
    </html>
    """
  end

  def app(assigns) do
    ~H"""
    <div class="layout">
      <aside class="sidebar">
        <div class="sidebar-header">
          <span class="sidebar-logo">LRP</span>
          <span class="sidebar-version">v0.1</span>
        </div>
        <nav class="sidebar-nav">
          <%= for {label, _path, icon} <- @nav_items do %>
            <.nav_item label={label} icon={icon} active={assigns[:active_nav]} />
          <% end %>
        </nav>
        <div class="sidebar-footer">
          <div class="sidebar-divider"></div>
          <.nav_item label="Admin" icon="admin" active={assigns[:active_nav]} />
          <div class="sidebar-user">
            <div class="sidebar-avatar">👤</div>
            <div class="sidebar-user-info">
              <span class="sidebar-user-name">Operator</span>
              <span class="sidebar-user-role">Admin</span>
            </div>
          </div>
        </div>
      </aside>
      <main class="main-content">
        <div class="content-wrapper">
          <%= @inner_content %>
        </div>
      </main>
      <.live_component module={LRPWeb.Components.AgentBar} id="agent-bar" />
    </div>
    """
  end
end
