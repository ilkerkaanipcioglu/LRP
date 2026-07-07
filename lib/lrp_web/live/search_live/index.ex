defmodule LRPWeb.SearchLive.Index do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    tenants = LRP.list_tenants()
    tenant = List.first(tenants)

    {:ok,
     socket
     |> assign(:tenant, tenant)
     |> assign(:query, "")
     |> assign(:results, nil)
     |> assign(:active_nav, "mail")
     |> assign(:page_title, "Search")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    query = String.trim(query)
    results =
      if query != "" and socket.assigns.tenant do
        LRP.search(socket.assigns.tenant.id, query)
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:results, results)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <div>
        <h1 class="page-title">Search</h1>
        <p class="page-subtitle">Search across objects, events and tasks</p>
      </div>
    </div>

    <div class="card">
      <form phx-submit="search" class="search-form">
        <input
          type="text"
          name="query"
          value={@query}
          placeholder="Type to search..."
          class="search-input"
          autofocus
        />
        <button type="submit" class="search-btn">Search</button>
      </form>

      <%= if is_nil(@results) do %>
        <div class="card-empty">
          <div class="empty-icon">🔍</div>
          <h3>Search LRP Data</h3>
          <p>Type a query to search across objects, events and tasks.</p>
        </div>
      <% else %>
        <%= render_results(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_results(assigns) do
    has_results =
      assigns.results.objects != [] or
      assigns.results.events != [] or
      assigns.results.process_tasks != []

    assigns = assign(assigns, :has_results, has_results)

    ~H"""
    <%= if @has_results do %>
      <div :if={@results.objects != []} class="search-group">
        <h3 class="search-group-title">
          Objects <span class="badge"><%= length(@results.objects) %></span>
        </h3>
        <div class="search-results">
          <div :for={obj <- @results.objects} class="search-result-item">
            <div class="search-result-type"><%= obj.type %></div>
            <div class="search-result-name"><%= obj.name %></div>
          </div>
        </div>
      </div>

      <div :if={@results.events != []} class="search-group">
        <h3 class="search-group-title">
          Events <span class="badge"><%= length(@results.events) %></span>
        </h3>
        <div class="search-results">
          <div :for={event <- @results.events} class="search-result-item">
            <div class="search-result-type"><%= event.event_type %></div>
            <div class="search-result-name"><%= event.payload["from"] || event.payload["subject"] || "Event" %></div>
            <div class="search-result-meta"><%= format_date(event.occurred_at) %></div>
          </div>
        </div>
      </div>

      <div :if={@results.process_tasks != []} class="search-group">
        <h3 class="search-group-title">
          Tasks <span class="badge"><%= length(@results.process_tasks) %></span>
        </h3>
        <div class="search-results">
          <div :for={task <- @results.process_tasks} class="search-result-item">
            <div class="search-result-type"><%= task.process_name %></div>
            <div class="search-result-name"><%= task.name %></div>
            <div class="search-result-meta"><%= task.status %></div>
          </div>
        </div>
      </div>
    <% else %>
      <div class="card-empty">
        <div class="empty-icon">🔍</div>
        <h3>No results found</h3>
        <p>Try a different search term.</p>
      </div>
    <% end %>
    """
  end

  defp format_date(nil), do: ""
  defp format_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%d %b %H:%M")
      _ -> date_string
    end
  end
end
