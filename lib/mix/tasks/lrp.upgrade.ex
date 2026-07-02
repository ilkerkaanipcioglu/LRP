defmodule Mix.Tasks.Lrp.Upgrade do
  use Mix.Task
  alias LRP.CliHelpers, as: H
  alias LRP.Codegen.ElixirGenerator

  @shortdoc "LRP Blueprint tasarım (.md) belgelerini çalışan koda yükseltir"

  @moduledoc """
  LRP Blueprint (.md) tasarım belgelerini çalışan koda (Elixir migration + schema + context) yükseltir.

  ## Kullanım

      mix lrp.upgrade --from=md-only --to=elixir
      mix lrp.upgrade --from=md-only --to=elixir --migrate

  ## Seçenekler

      --from     Kaynak tasarım türü (varsayılan: md-only)
      --to       Hedef programlama dili/teknoloji (varsayılan: elixir) (desteklenen: elixir)
      --dir      Tasarım belgelerinin yolu (varsayılan: docs/lrp-design)
      --migrate  Kod üretiminden sonra veritabanı migration'ını otomatik çalıştır
  """

  @switches [from: :string, to: :string, dir: :string, migrate: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    from = Keyword.get(opts, :from, "md-only")
    to   = Keyword.get(opts, :to, "elixir")
    dir  = Keyword.get(opts, :dir, "docs/lrp-design")
    run_migrate = Keyword.get(opts, :migrate, false)

    H.start_app()

    H.banner("LRP Code Upgrade Engine")
    IO.puts("  Kaynak Mod  : #{H.bold(from)}")
    IO.puts("  Hedef Dil   : #{H.green(to)}")
    IO.puts("  Tasarım Yolu: #{dir}")
    IO.puts("")

    cond do
      from == "md-only" and to == "elixir" ->
        case ElixirGenerator.upgrade_from_md(dir) do
          {:ok, generated_files} ->
            IO.puts(H.green("✓ Kod üretimi başarıyla tamamlandı!"))
            IO.puts("Üretilen Dosyalar:")
            Enum.each(generated_files, fn filepath ->
              IO.puts("  - #{H.dim(filepath)}")
            end)

            if run_migrate do
              IO.puts("\n🚀 Migration'lar çalıştırılıyor...")
              Mix.Task.run("ecto.migrate", [])
            else
              IO.puts("\n👉 Değişiklikleri veritabanına yansıtmak için çalıştırın:")
              IO.puts(H.cyan("   mix ecto.migrate"))
            end

          {:error, reason} ->
            IO.puts(H.red("❌ Hata: #{reason}"))
            System.halt(1)
        end

      true ->
        IO.puts(H.red("❌ Hata: --from=#{from} ve --to=#{to} kombinasyonu henüz desteklenmiyor."))
        IO.puts("Desteklenen: --from=md-only --to=elixir")
        System.halt(1)
    end
  end
end
