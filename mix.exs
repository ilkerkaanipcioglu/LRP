defmodule LRP.MixProject do
  use Mix.Project

  def project do
    [
      app: :lrp,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {LRP.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:ecto_sqlite3, "~> 0.12"},
      {:jason, "~> 1.4"},
      {:req, "~> 0.4"},
      {:broadway, "~> 1.0"},
      {:broadway_dashboard, "~> 0.4", only: :dev}
    ]
  end
end
