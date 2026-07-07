defmodule LRPWeb.Components.AgentCard do
  use LRPWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="agent-card">
      <div class="agent-card-header">
        <div class="agent-card-avatar">🤖</div>
        <div class="agent-card-info">
          <div class="agent-card-name"><%= @agent.name %></div>
          <span class={"agent-status #{@agent.status}"}><%= @agent.status %></span>
        </div>
      </div>
      <div class="agent-card-actions">
        <a href={"/agents/#{@agent.id}"} class="btn btn-sm">View Logs</a>
      </div>
    </div>
    """
  end
end
