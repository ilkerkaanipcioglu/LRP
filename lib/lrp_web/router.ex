defmodule LRPWeb.Router do
  use LRPWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LRPWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", LRPWeb do
    pipe_through :browser

    live "/", PageLive, :home

    live "/inbox", InboxLive.Index, :index
    live "/inbox/mail/:id", InboxLive.Show, :show
    live "/inbox/approvals", ApprovalsLive.Index, :index

    live "/workspace", PlaceholderLive, :workspace
    live "/workspace/calendar", PlaceholderLive, :workspace
    live "/workspace/notes", PlaceholderLive, :workspace
    live "/workspace/notes/:id", PlaceholderLive, :workspace
    live "/workspace/todos", PlaceholderLive, :workspace

    live "/agents", AgentsLive.Index, :index
    live "/agents/:id", AgentsLive.Show, :show
    live "/dashboard", DashboardLive.Index, :index
    live "/studio", StudioLive.Index, :index
    live "/studio/new", StudioLive.New, :new
    live "/studio/:id", StudioLive.Show, :show
    live "/apps", PlaceholderLive, :apps
    live "/admin", AdminLive.Index, :index
    live "/search", SearchLive.Index, :index
  end
end
