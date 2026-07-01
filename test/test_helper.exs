ExUnit.start(exclude: [:integration])

# Ensure repository directories exist
File.mkdir_p!("priv/repo")

# Clean old test DB to ensure a fresh schema build
File.rm("priv/repo/lrp_test.db")
File.rm("priv/repo/lrp_test.db-shm")
File.rm("priv/repo/lrp_test.db-wal")

# Run migrations using ecto's recommended with_repo
{:ok, _, _} = Ecto.Migrator.with_repo(LRP.Repo, &Ecto.Migrator.run(&1, :up, all: true))

Ecto.Adapters.SQL.Sandbox.mode(LRP.Repo, :manual)
