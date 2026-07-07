defmodule LRPWeb.StudioLive.Index do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    projects = LRP.list_projects()
    companies = LRP.list_companies()

    {:ok,
     socket
     |> assign(:projects, projects)
     |> assign(:companies, companies)
     |> assign(:page_title, "Studio")
     |> assign(:active_nav, "film")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div class="page-header-row">
        <div>
          <h1 class="page-title">Studio</h1>
          <p class="page-subtitle">Project management and development wizard</p>
        </div>
        <a href="/studio/new" class="btn">+ New Project</a>
      </div>
    </div>

    <%= if @projects == [] do %>
      <div class="empty-state">
        <div class="empty-icon">🎬</div>
        <h3>No projects yet</h3>
        <p>Create your first project to get started.</p>
        <a href="/studio/new" class="btn" style="margin-top: 16px;">Create Project</a>
      </div>
    <% else %>
      <div class="studio-grid">
        <%= for project <- @projects do %>
          <a href={"/studio/#{project.id}"} class="project-card">
            <div class="project-card-header">
              <div class="project-card-icon">🎬</div>
              <div>
                <div class="project-card-name"><%= project.name %></div>
                <div class="project-card-db"><%= truncate_db(project.database_url) %></div>
              </div>
            </div>
            <div class="project-card-meta">
              <span class="project-card-id mono"><%= project.id %></span>
            </div>
          </a>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp truncate_db(nil), do: "No DB"
  defp truncate_db(url), do: url
end
