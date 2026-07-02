defmodule LRP.Codegen.ElixirGenerator do
  @moduledoc """
  Elixir kod üretici — migration + schema + context dosyaları üretir.

  Hem yeni sistem için hem de md-only → elixir yükseltme senaryosu için kullanılır.
  """

  @doc """
  Bir capability için Elixir migration dosyası üretir.

  ## Parametreler
  - `capability_type` — "email" | "slack" | ...
  - `output_dir`      — hedef lib/ dizini
  - `opts`            — [timestamp:, fields:]
  """
  @spec generate_migration(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_migration(capability_type, output_dir \\ "priv/repo/migrations", opts \\ []) do
    ts       = Keyword.get(opts, :timestamp, migration_timestamp())
    filename = "#{ts}_create_#{capability_type}_capability.exs"
    filepath = Path.join(output_dir, filename)

    content = migration_template(capability_type, opts)

    with :ok <- File.mkdir_p(output_dir),
         :ok <- File.write(filepath, content) do
      {:ok, filepath}
    end
  end

  @doc """
  Bir capability için Elixir schema modülü üretir.
  """
  @spec generate_schema(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_schema(capability_type, output_dir \\ "lib/lrp", opts \\ []) do
    module_name = Macro.camelize(capability_type)
    filename    = "#{capability_type}_schema.ex"
    filepath    = Path.join(output_dir, filename)

    content = schema_template(capability_type, module_name, opts)

    with :ok <- File.mkdir_p(output_dir),
         :ok <- File.write(filepath, content) do
      {:ok, filepath}
    end
  end

  @doc """
  Bir capability için Elixir context modülü üretir.
  """
  @spec generate_context(String.t(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def generate_context(capability_type, output_dir \\ "lib/lrp", opts \\ []) do
    module_name = Macro.camelize(capability_type)
    filename    = "#{capability_type}_context.ex"
    filepath    = Path.join(output_dir, filename)

    content = context_template(capability_type, module_name, opts)

    with :ok <- File.mkdir_p(output_dir),
         :ok <- File.write(filepath, content) do
      {:ok, filepath}
    end
  end

  @doc """
  md-only tasarım belgelerini okuyarak Elixir dosyalarına yükseltir.
  `mix lrp.upgrade --from=md-only --to=elixir` bu fonksiyonu çağırır.

  ## Parametreler
  - `md_dir`       — md-only belgelerinin dizini (varsayılan: "docs/lrp-design")
  - `output_dir`   — Elixir dosyaları için hedef dizin
  """
  @spec upgrade_from_md(String.t(), keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def upgrade_from_md(md_dir \\ "docs/lrp-design", opts \\ []) do
    cap_dir = Path.join(md_dir, "capabilities")

    case File.ls(cap_dir) do
      {:ok, files} ->
        lib_dir  = Keyword.get(opts, :lib_dir, "lib/lrp")
        mig_dir  = Keyword.get(opts, :mig_dir, "priv/repo/migrations")

        results =
          files
          |> Enum.filter(&String.ends_with?(&1, ".md"))
          |> Enum.flat_map(fn file ->
            cap_type = String.replace(file, ".md", "")
            filepath = Path.join(cap_dir, file)
            
            # Parse YAML frontmatter from md blueprint
            metadata = parse_frontmatter(filepath)
            interface_contract = Map.get(metadata, :interface_contract, %{})

            {:ok, mig_path}  = generate_migration(cap_type, mig_dir)
            {:ok, sch_path}  = generate_schema(cap_type, lib_dir)
            {:ok, ctx_path}  = generate_context(cap_type, lib_dir, interface_contract: interface_contract)

            [mig_path, sch_path, ctx_path]
          end)

        {:ok, results}

      {:error, _} ->
        {:error, "#{cap_dir} dizini bulunamadı. md-only modu başlatıldı mı?"}
    end
  end

  defp parse_frontmatter(filepath) do
    content = File.read!(filepath)
    case String.split(content, "---") do
      ["", yaml_content | _rest] ->
        parse_yaml(yaml_content)
      _ ->
        %{interface_contract: %{}}
    end
  end

  defp parse_yaml(yaml_str) do
    lines = String.split(yaml_str, ~r/\r?\n/)
    Enum.reduce(lines, %{interface_contract: %{}}, fn line, acc ->
      trimmed = String.trim(line)
      cond do
        trimmed == "" ->
          acc
        
        String.contains?(line, ":") ->
          [key, val] = String.split(line, ":", parts: 2)
          key = String.trim(key)
          val = String.trim(val)

          if key == "interface_contract" or String.starts_with?(line, "  ") do
            if String.starts_with?(line, "  ") do
              [fn_name, fn_desc] = String.split(trimmed, ":", parts: 2)
              fn_name = String.trim(fn_name)
              fn_desc = String.trim(fn_desc)
              fn_desc = String.replace(fn_desc, ~r/^["']|["']$/, "")
              
              new_contract = Map.put(acc.interface_contract, fn_name, fn_desc)
              Map.put(acc, :interface_contract, new_contract)
            else
              acc
            end
          else
            val = String.replace(val, ~r/^["']|["']$/, "")
            Map.put(acc, String.to_atom(key), val)
          end

        true ->
          acc
      end
    end)
  end

  # ── Şablonlar ─────────────────────────────────────────────────────────────────

  defp migration_template(capability_type, _opts) do
    table = "#{capability_type}_records"

    """
    # Bu dosya `mix lrp.upgrade --from=md-only --to=elixir` tarafından üretilmiştir.
    # Capability: #{capability_type}
    # LRP Object Graph üzerinde çalışır — çekirdek tablolara dokunmaz.
    defmodule LRP.Repo.Migrations.Create#{Macro.camelize(capability_type)}Capability do
      use Ecto.Migration

      def change do
        # #{capability_type} capability'ye ait ek veri tablosu.
        # LRP çekirdeği (OBJECT/EVENT) zaten bu veriyi tutabilir;
        # domain-spesifik alanlar için bu tablo ekleniyor.
        create table(:#{table}, primary_key: false) do
          add :id,           :binary_id, primary_key: true
          add :tenant_id,    references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
          add :object_id,    references(:objects, type: :binary_id, on_delete: :delete_all)
          add :capability_id, references(:capabilities, type: :binary_id), null: false
          add :metadata,     :map, default: %{}
          add :status,       :string, default: "active"
          timestamps()
        end

        create index(:#{table}, [:tenant_id])
        create index(:#{table}, [:capability_id])
        create index(:#{table}, [:object_id])
      end
    end
    """
  end

  defp schema_template(capability_type, module_name, _opts) do
    table = "#{capability_type}_records"

    """
    # Bu dosya `mix lrp.upgrade --from=md-only --to=elixir` tarafından üretilmiştir.
    defmodule LRP.#{module_name}Schema do
      use Ecto.Schema
      import Ecto.Changeset

      @moduledoc \"\"\"
      #{capability_type} capability için schema modülü.
      LRP Object Graph protokolüne uygun — OBJECT/EVENT çekirdeğine bağlı.
      \"\"\"

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      schema "#{table}" do
        field :tenant_id,     :binary_id
        field :object_id,     :binary_id
        field :capability_id, :binary_id
        field :metadata,      :map, default: %{}
        field :status,        :string, default: "active"
        timestamps()
      end

      def changeset(record, attrs) do
        record
        |> cast(attrs, [:tenant_id, :object_id, :capability_id, :metadata, :status])
        |> validate_required([:tenant_id, :capability_id])
      end
    end
    """
  end

  defp context_template(capability_type, module_name, opts) do
    interface = Keyword.get(opts, :interface_contract, %{}) || %{}

    dynamic_interface =
      Enum.reject(interface, fn {sig, _} ->
        sig in ["create/1", "get/1", "list/1"]
      end)

    dynamic_functions =
      Enum.map(dynamic_interface, fn {fn_signature, fn_desc} ->
        case String.split(fn_signature, "/") do
          [fn_name, arity_str] ->
            arity = String.to_integer(arity_str)
            args =
              if arity > 0 do
                1..arity |> Enum.map(fn i -> "arg#{i}" end) |> Enum.join(", ")
              else
                ""
              end

            """
              @doc "#{fn_desc}"
              def #{fn_name}(#{args}) do
                # TODO: Implement #{fn_name}/#{arity} for #{capability_type}
                {:error, :not_implemented}
              end
            """

          _ ->
            ""
        end
      end)
      |> Enum.join("\n")

    """
    # Bu dosya `mix lrp.upgrade --from=md-only --to=elixir` tarafından üretilmiştir.
    defmodule LRP.#{module_name} do
      @moduledoc \"\"\"
      #{capability_type} capability context modülü.
      LRP.Capability.Manager ile entegre çalışır.
      \"\"\"

      alias LRP.Repo
      alias LRP.#{module_name}Schema

      @doc "Yeni #{capability_type} kaydı oluşturur."
      def create(attrs) do
        %#{module_name}Schema{}
        |> #{module_name}Schema.changeset(attrs)
        |> Repo.insert()
      end

      @doc "#{capability_type} kaydını getirir."
      def get(id), do: Repo.get(#{module_name}Schema, id)

      @doc "#{capability_type} kayıtlarını listeler."
      def list(tenant_id) do
        import Ecto.Query
        from(r in #{module_name}Schema, where: r.tenant_id == ^tenant_id)
        |> Repo.all()
      end

      # ─── Dinamik Kontrat Fonksiyonları ─────────────────────────────────────────
    #{dynamic_functions}
    end
    """
  end

  defp migration_timestamp do
    now = DateTime.utc_now()
    "#{now.year}#{pad2(now.month)}#{pad2(now.day)}#{pad2(now.hour)}#{pad2(now.minute)}#{pad2(now.second)}"
  end

  defp pad2(n), do: String.pad_leading(Integer.to_string(n), 2, "0")
end
