defmodule LRPWeb.Components.AgentBar do
  use LRPWeb, :live_component

  @conversation_id "default-agent-conv"

  @impl true
  def update(assigns, socket) do
    if assigns[:open?] != nil do
      {:ok, socket |> assign(:open, assigns[:open?])}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle", _, socket) do
    {:noreply, assign(socket, :open, not socket.assigns.open)}
  end

  @impl true
  def handle_event("send_message", %{"message" => msg}, socket) do
    msg = String.trim(msg)
    if msg != "" do
      tenants = LRP.list_tenants()
      tenant = List.first(tenants)
      if tenant do
        LRP.send_agent_chat_message(tenant.id, @conversation_id, msg)
        messages = LRP.list_agent_chat_messages(@conversation_id)
        {:noreply, assign(socket, :messages, messages)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={["agent-bar", assigns.open && "agent-bar--open"]}>
      <div class="agent-bar-header">
        <span class="agent-bar-title">🤖 Agent</span>
        <button phx-click="toggle" class="agent-bar-close">&times;</button>
      </div>
      <div class="agent-bar-messages">
        <%= for msg <- @messages || [] do %>
          <div class="agent-msg">
            <div class="agent-msg-sender">
              <%= msg.payload["actor_id"] || "User" %>
            </div>
            <div class="agent-msg-text">
              <%= msg.payload["message"] %>
            </div>
          </div>
        <% end %>
      </div>
      <div class="agent-bar-input">
        <form phx-submit="send_message" phx-target="#{@id}">
          <input
            type="text"
            name="message"
            placeholder="Type a message..."
            class="agent-input"
            autocomplete="off"
            phx-keydown="keydown"
          />
          <button type="submit" class="agent-send-btn">Send</button>
        </form>
      </div>
    </div>

    <button
      phx-click="toggle"
      class={["agent-toggle-btn", assigns.open && "agent-toggle-btn--active"]}
      title="Toggle Agent Chat"
    >
      🤖
    </button>
    """
  end
end
