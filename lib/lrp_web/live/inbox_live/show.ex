defmodule LRPWeb.InboxLive.Show do
  use LRPWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    document = LRP.get_object(id)
    events = if document, do: LRP.list_document_events(id), else: []
    related_objects =
      if document do
        LRP.list_related_objects(id)
      else
        []
      end

    {:ok,
     socket
     |> assign(:document, document)
     |> assign(:events, events)
     |> assign(:related_objects, related_objects)
     |> assign(:page_title, if(document, do: document.name, else: "Not Found"))
     |> assign(:active_nav, "mail")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-header">
      <a href={~p"/inbox"} class="back-link">← Inbox</a>
    </div>

    <%= if @document do %>
      <div class="mail-detail">
        <div class="mail-detail-main">
          <div class="mail-detail-card">
            <div class="mail-subject"><%= @document.name %></div>
            <div class="mail-meta-row">
              <span class="mail-from">From: <%= @document.metadata["from"] %></span>
              <span class="mail-to">To: <%= @document.metadata["to"] %></span>
              <span class="mail-date">
                <%= format_date(@document.metadata["received_at"]) %>
              </span>
            </div>
          </div>
          <div class="mail-body-card">
            <h4>Body Preview</h4>
            <p class="mail-body">
              <%= @document.metadata["body_preview"] || "(no preview)" %>
            </p>
          </div>
        </div>
        <div class="mail-detail-sidebar">
          <h3>Thread & Events</h3>
          <%= if @events == [] do %>
            <p class="thread-empty">No related events yet.</p>
          <% else %>
            <div class="event-list">
              <%= for event <- @events do %>
                <div class="event-item">
                  <div class="event-type"><%= event.event_type %></div>
                  <div class="event-time"><%= format_date(event.occurred_at) %></div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="empty-state">
        <div class="empty-icon">📭</div>
        <h3>Document not found</h3>
      </div>
    <% end %>
    """
  end

  defp format_date(nil), do: ""
  defp format_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, dt, _} -> Calendar.strftime(dt, "%d %b %Y %H:%M")
      _ -> date_string
    end
  end
end
