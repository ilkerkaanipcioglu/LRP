defmodule LRP.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LRP.Repo,
      LRPWeb.Telemetry,
      {Phoenix.PubSub, name: LRP.PubSub},
      LRPWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: LRP.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
