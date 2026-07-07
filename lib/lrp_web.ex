defmodule LRPWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use LRPWeb, :controller
      use LRPWeb, :html

  Define `build/1`, `build/2`, `build/3`, `build/4`, `build/5`
  each time you want to define a new view/component/layout.
  """

  def static_routes, do: ~w(/assets /images /fonts /favicon.ico)

  def endpoint, do: LRPWeb.Endpoint

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def html do
    quote do
      use Phoenix.Component

      unquote(html_helpers())
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: LRPWeb.Layouts]

      import Plug.Conn
      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {LRPWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      import Phoenix.LiveView.Helpers
      import Phoenix.LiveView.TagEngine

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  defp verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: LRPWeb.Endpoint,
        router: LRPWeb.Router,
        statics: LRPWeb.static_routes()
    end
  end
end
