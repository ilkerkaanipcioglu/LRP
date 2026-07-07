defmodule LRPWeb.StudioLive.Show do
  use LRPWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = LRP.get_project(id)
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)

    related_objects =
      if tenant do
        LRP.list_objects_by_tenant_and_type(tenant.id, "Software")
        |> Enum.filter(fn obj ->
              is_map(obj.metadata) and obj.metadata["project_id"] == id
            end)
      else
        []
      end

    related_tasks =
      if tenant do
        LRP.list_recent_events(tenant.id, 10)
      else
        []
      end

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:related_objects, related_objects)
     |> assign(:recent_events, related_tasks)
     |> assign(:page_title, if(project, do: project.name, else: "Project Not Found"))
     |> assign(:active_nav, "film")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <a href="/studio" class="back-link">← Studio</a>
    </div>

    <%= if @project do %>
      <div class="project-detail-header">
        <div class="project-detail-icon">🎬</div>
        <div>
          <h2 class="project-detail-name"><%= @project.name %></h2>
          <div class="project-detail-meta">
            <span class="badge">Project</span>
            <span class="mono"><%= @project.id %></span>
          </div>
        </div>
      </div>

      <div class="project-detail-grid">
        <div class="card">
          <div class="card-header">
            <span>Project Info</span>
          </div>
          <div class="tenant-info">
            <div class="info-row">
              <span class="info-label">Database</span>
              <span class="info-value mono"><%= @project.database_url %></span>
            </div>
            <div class="info-row">
              <span class="info-label">Description</span>
              <span class="info-value"><%= @project.metadata["description"] || "(none)" %></span>
            </div>
            <div class="info-row">
              <span class="info-label">Created</span>
              <span class="info-value"><%= format_dt(@project.inserted_at) %></span>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="card-header">
            <span>Software Modules</span>
            <span class="badge"><%= length(@related_objects) %></span>
          </div>
          <%= if @related_objects == [] do %>
            <div class="card-empty">
              <p class="thread-empty">No software modules linked yet.</p>
            </div>
          <% else %>
            <div class="event-feed">
              <%= for obj <- @related_objects do %>
                <div class="event-feed-item">
                  <div class="event-feed-type"><%= obj.type %></div>
                  <div class="event-feed-source"><%= obj.name %></div>
                  <div class="event-feed-time"><%= format_dt(obj.inserted_at) %></div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="card">
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
      </div>
    <% else %>
      <div class="empty-state">
        <div class="empty-icon">🎬</div>
        <h3>Project not found</h3>
      </div>
    <% end %>
    """
  end

  defp format_dt(nil), do: ""
  defp format_dt(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
  defp format_dt(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y %H:%M")
  defp format_dt(dt) when is_binary(dt) do
    case DateTime.from_iso8601(dt) do
      {:ok, d, _} -> Calendar.strftime(d, "%d %b %Y %H:%M")
      _ -> dt
    end
  end
end
