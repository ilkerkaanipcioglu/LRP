import Config

config :lrp, LRP.Repo,
  database: "priv/repo/lrp_dev.db",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
