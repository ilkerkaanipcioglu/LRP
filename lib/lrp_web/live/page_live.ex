defmodule LRPWeb.PageLive do
  use LRPWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: "/inbox")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div></div>
    """
  end
end
