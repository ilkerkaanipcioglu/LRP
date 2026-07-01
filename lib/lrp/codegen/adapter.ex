defmodule LRP.Codegen.Adapter do
  @moduledoc """
  output_mode → doğru generator seçici.

  v1: "elixir" | "md-only"
  v2: Rust, Python, Go, PHP (GitHub analizi ile)
  """

  alias LRP.Codegen.{ElixirGenerator, MdOnly}

  @supported_modes_v1 ~w(elixir md-only)

  @doc """
  Seçilen çıktı moduna göre doğru generator'ı çağırır.

  ## Parametreler
  - `output_mode`  — "elixir" | "md-only"
  - `capabilities` — capability listesi
  - `opts`         — [output_dir:, system_name:]
  """
  @spec generate(String.t(), [map()], keyword()) ::
          {:ok, [String.t()]} | {:error, term()}
  def generate(output_mode, capabilities, opts \\ [])

  def generate("md-only", capabilities, opts) do
    output_dir = Keyword.get(opts, :output_dir, "docs/lrp-design")

    MdOnly.generate_all(%{
      capabilities: capabilities,
      output_dir:   output_dir,
      system_name:  Keyword.get(opts, :system_name, "LRP Sistemi")
    })
  end

  def generate("elixir", capabilities, opts) do
    lib_dir = Keyword.get(opts, :lib_dir, "lib/lrp")
    mig_dir = Keyword.get(opts, :mig_dir, "priv/repo/migrations")

    results =
      Enum.flat_map(capabilities, fn cap ->
        cap_type = cap[:type]
        {:ok, mig}  = ElixirGenerator.generate_migration(cap_type, mig_dir)
        {:ok, sch}  = ElixirGenerator.generate_schema(cap_type, lib_dir)
        {:ok, ctx}  = ElixirGenerator.generate_context(cap_type, lib_dir)
        [mig, sch, ctx]
      end)

    {:ok, results}
  end

  def generate(mode, _capabilities, _opts) when mode not in @supported_modes_v1 do
    {:error,
     """
     Desteklenmeyen output_mode: "#{mode}"

     v1'de desteklenen modlar: #{Enum.join(@supported_modes_v1, ", ")}

     v2'de eklenecekler: rust, python, go, php
     (GitHub repo analizi ile otomatik tespit)
     """}
  end

  @doc "Mevcut md-only tasarımını Elixir koduna yükseltir."
  @spec upgrade_md_to_elixir(keyword()) :: {:ok, [String.t()]} | {:error, term()}
  def upgrade_md_to_elixir(opts \\ []) do
    md_dir = Keyword.get(opts, :md_dir, "docs/lrp-design")
    ElixirGenerator.upgrade_from_md(md_dir, opts)
  end
end
