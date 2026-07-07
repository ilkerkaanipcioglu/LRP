import Config

config :lrp, LRP.Repo,
  database: "priv/repo/lrp_dev.db",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :lrp, LRPWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :lrp, LRPWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(css|png|jpeg|jpg|gif|svg)$},
      ~r{lib/lrp_web/.*(ex|heex)$}
    ]
  ]
