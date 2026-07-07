import Config

config :lrp, LRP.Repo,
  database: "priv/repo/lrp_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :lrp, LRPWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false
