defmodule LRPWeb.PlaceholderLive do
  use LRPWeb, :live_view

  @sections %{
    workspace: {"Workspace", "Takvim, not ve gorev yonetimi", "📅", "v3"},
    agents: {"Agents", "Agent yonetimi ve log'lar", "🤖", "v1c"},
    studio: {"Studio", "Proje gelistirme sihirbazi", "🎬", "v2"},
    apps: {"Uygulamalar", "Tenant uygulamalari ve widget'lar", "📱", "v4"},
    admin: {"Admin", "Sistem yonetimi ve connector'lar", "⚙️", "v1c"},
    dashboard: {"Dashboard", "Sistem durumu ve event akisi", "📊", "v1c"},
    search: {"Search", "Global arama (Faz 1b)", "🔍", "v1b"}
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket, temporary_redirects: []}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    section = socket.assigns.live_action

    {title, description, icon, phase} = Map.get(@sections, section, {"LRP", "", "📦", ""})

    nav_key =
      case section do
        :workspace -> "calendar"
        :agents -> "bot"
        :studio -> "film"
        :apps -> "apps"
        :admin -> "admin"
        :dashboard -> "mail"
        :search -> "mail"
        _ -> "mail"
      end

    {:noreply,
     socket
     |> assign(:section_title, title)
     |> assign(:section_description, description)
     |> assign(:section_icon, icon)
     |> assign(:section_phase, phase)
     |> assign(:active_nav, nav_key)
     |> assign(:page_title, title)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <h1 class="page-title"><%= @section_icon %> <%= @section_title %></h1>
        <p class="page-subtitle"><%= @section_description %></p>
      </div>
    </div>

    <div class="placeholder-state">
      <div class="placeholder-icon"><%= @section_icon %></div>
      <h2 class="placeholder-title"><%= @section_title %></h2>
      <p class="placeholder-description">
        Bu modul "<%= @section_phase %>" fazinda implemente edilecektir.
      </p>
      <div class="placeholder-info">
        <p>
          LRP backend motoru hazir. Bu sayfanin arka planda kullandigi
          API fonksiyonlari (<code>LRP.list_objects_by_tenant/1</code>,
          <code>LRP.create_process_task/1</code> vb.) mevcut.
        </p>
      </div>
    </div>
    """
  end
end
