import Config

config :lrp,
  ecto_repos: [LRP.Repo],
  pubsub_server: LRP.PubSub

config :lrp, LRP.PubSub,
  adapter: Phoenix.PubSub.PG2,
  pool_size: 4

config :lrp, LRPWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: LRPWeb.ErrorHTML, json: LRPWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: LRP.PubSub,
  live_view: [signing_salt: "AAAAAAAA"]

config :lrp, LRP.Repo,
  database: "priv/repo/lrp_dev.db",
  journal_mode: :wal,
  cache_size: -64000,
  temp_store: :memory,
  pool_size: 10

import_config "#{config_env()}.exs"
