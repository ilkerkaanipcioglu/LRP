defmodule LRP.Repo do
  use Ecto.Repo,
    otp_app: :lrp,
    adapter: Ecto.Adapters.SQLite3
end
