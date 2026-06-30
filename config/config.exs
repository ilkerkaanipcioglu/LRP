import Config

config :lrp,
  ecto_repos: [LRP.Repo]

config :lrp, LRP.Repo,
  database: "priv/repo/lrp_dev.db",
  journal_mode: :wal,
  cache_size: -64000,
  temp_store: :memory,
  pool_size: 10

import_config "#{config_env()}.exs"
