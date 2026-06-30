import Config

config :lrp, LRP.Repo,
  database: "priv/repo/lrp_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
