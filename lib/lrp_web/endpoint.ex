defmodule LRPWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :lrp

  @session_options [
    store: :cookie,
    key: "_lrp_key",
    signing_salt: "BBBBBBBB"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    check_origin: ["//"]

  plug Plug.Static,
    at: "/",
    from: :lrp,
    gzip: false,
    only: ~w(assets fonts images favicon.ico favicon-16x16.png favicon-32x32.png)

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.Session, @session_options
  plug LRPWeb.Router
end
