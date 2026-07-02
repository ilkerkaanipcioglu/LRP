defmodule LRP.ModernizerTest do
  use ExUnit.Case, async: false

  setup do
    # Temp directories for legacy project and generated LRP output
    tmp_legacy_dir = Path.join([File.cwd!(), "tmp", "legacy-project"])
    tmp_output_dir = Path.join([File.cwd!(), "tmp", "modernized-output"])
    tmp_lib_dir    = Path.join([File.cwd!(), "tmp", "lib-test"])
    tmp_mig_dir    = Path.join([File.cwd!(), "tmp", "mig-test"])

    File.mkdir_p!(tmp_legacy_dir)
    File.mkdir_p!(tmp_output_dir)
    File.mkdir_p!(tmp_lib_dir)
    File.mkdir_p!(tmp_mig_dir)

    on_exit(fn ->
      File.rm_rf!(Path.join(File.cwd!(), "tmp"))
    end)

    {:ok, legacy_dir: tmp_legacy_dir, output_dir: tmp_output_dir, lib_dir: tmp_lib_dir, mig_dir: tmp_mig_dir}
  end

  test "modernize/2 discovers entities and generates LRP markdown specs (target: md)", context do
    # 1. Create dummy legacy project structure
    # A Rails-like migration file
    rails_migration_dir = Path.join(context.legacy_dir, "db/migrate")
    File.mkdir_p!(rails_migration_dir)
    File.write!(Path.join(rails_migration_dir, "20240101000000_create_products.rb"), """
    class CreateProducts < ActiveRecord::Migration[7.0]
      def change
        create_table :products do |t|
          t.string :name
          t.decimal :price
          t.timestamps
        end
      end
    end
    """)

    # A Prisma schema file
    prisma_dir = Path.join(context.legacy_dir, "prisma")
    File.mkdir_p!(prisma_dir)
    File.write!(Path.join(prisma_dir, "schema.prisma"), """
    datasource db {
      provider = "postgresql"
      url      = env("DATABASE_URL")
    }

    model Order {
      id        Int      @id @default(autoincrement())
      createdAt DateTime @default(now())
      total     Int
    }
    """)

    # 2. Run modernizer targeting markdown
    assert {:ok, generated_files} = LRP.Modernizer.modernize(context.legacy_dir,
      target: "md",
      output_dir: context.output_dir
    )

    # 3. Verify generated markdown files
    assert Enum.any?(generated_files, &String.contains?(&1, "README.md"))
    assert Enum.any?(generated_files, &String.contains?(&1, "products.md"))
    assert Enum.any?(generated_files, &String.contains?(&1, "order.md"))

    # Check checklist injection
    readme_content = File.read!(Path.join(context.output_dir, "README.md"))
    assert readme_content =~ "LRP Migration Checklist (FİKİRLER)"
    assert readme_content =~ "Core Independence"
    assert readme_content =~ "Event Sourcing"
    assert readme_content =~ "Idempotency"

    # Check capability contents
    product_md = File.read!(Path.join([context.output_dir, "capabilities", "products.md"]))
    assert product_md =~ "capability: products"
    assert product_md =~ "create/1"
    assert product_md =~ "search/2"
  end

  test "modernize/2 generates Elixir schema, context and migrations (target: elixir)", context do
    # 1. Create a simple SQL schema file
    File.write!(Path.join(context.legacy_dir, "schema.sql"), """
    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255) NOT NULL,
      password_hash VARCHAR(255)
    );
    """)

    # 2. Run modernizer targeting Elixir
    assert {:ok, generated_files} = LRP.Modernizer.modernize(context.legacy_dir,
      target: "elixir",
      output_dir: context.output_dir,
      lib_dir: context.lib_dir,
      mig_dir: context.mig_dir
    )

    # 3. Verify both markdown and Elixir files are generated
    assert Enum.any?(generated_files, &String.contains?(&1, "users.md"))
    assert Enum.any?(generated_files, &String.contains?(&1, "users_schema.ex"))
    assert Enum.any?(generated_files, &String.contains?(&1, "users_context.ex"))
    assert Enum.any?(generated_files, &String.contains?(&1, "create_users_capability.exs"))

    # Check Elixir context content
    [context_file] = Enum.filter(generated_files, &String.contains?(&1, "users_context.ex"))
    context_content = File.read!(context_file)
    assert context_content =~ "defmodule LRP.Users"
    assert context_content =~ "def create(attrs)"
    assert context_content =~ "def search(arg1, arg2)"
  end
end
