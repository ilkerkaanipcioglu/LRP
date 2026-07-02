defmodule Mix.Tasks.Lrp.Modernize do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "Legacy uygulamayı analiz edip LRP standartlarında mimari (.md) veya Elixir kodu üretir"

  @moduledoc """
  Eski bir yazılım klasörünü veya GitHub reposunu analiz ederek:
    - LRP standartlarında Capabilities & Providers (.md) tasarım belgeleri üretir.
    - VEYA doğrudan Elixir Migration, Schema ve Context modülleri üretir.

  ## Kullanım

      mix lrp.modernize --source /path/to/legacy-app
      mix lrp.modernize --source /path/to/legacy-app --target elixir
      mix lrp.modernize --source https://github.com/user/old-repo --target md --output-dir custom-design

  ## Seçenekler

      --source      Analiz edilecek kaynak kod dizini veya GitHub URL (zorunlu)
      --target      Üretilecek çıktı türü: `md` veya `elixir` (varsayılan: `md`)
      --output-dir  Tasarım belgelerinin üretileceği dizin (varsayılan: `docs/lrp-design`)
  """

  @switches [source: :string, target: :string, output_dir: :string, token: :string]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    source     = Keyword.get(opts, :source)
    target     = Keyword.get(opts, :target, "md")
    output_dir = Keyword.get(opts, :output_dir, "docs/lrp-design")

    unless source do
      IO.puts(H.red("❌ --source parametresi gereklidir."))
      IO.puts("   Örnek: mix lrp.modernize --source /path/to/legacy-app")
      IO.puts("\n📖 Detaylı kılavuz ve yardım için: #{H.cyan("docs/MODERNIZER.md")}")
      System.halt(1)
    end

    unless target in ["md", "elixir"] do
      IO.puts(H.red("❌ Geçersiz --target değeri: #{target}. Yalnızca `md` veya `elixir` desteklenir."))
      System.halt(1)
    end

    H.start_app()

    H.banner("LRP Legacy Modernizer MVP")
    IO.puts("  Kaynak Dizin: #{H.cyan(source)}")
    IO.puts("  Hedef Çıktı : #{H.green(target)}")
    IO.puts("  Çıktı Yolu  : #{output_dir}")
    IO.puts("")

    IO.puts("🔍 Kaynak kod taranıyor ve entitiler keşfediliyor...")

    case LRP.Modernizer.modernize(source, opts) do
      {:ok, generated_files} ->
        IO.puts(H.green("\n✓ Modernizasyon çıktısı başarıyla üretildi!"))
        IO.puts("Üretilen Dosyalar:")
        Enum.each(generated_files, fn filepath ->
          IO.puts("  - #{H.dim(filepath)}")
        end)
        
        if target == "elixir" do
          IO.puts("\n👉 Değişiklikleri veritabanına yansıtmak için çalıştırın:")
          IO.puts(H.cyan("   mix ecto.migrate"))
        end

      {:error, reason} ->
        IO.puts(H.red("\n❌ Modernizasyon başarısız: #{reason}"))
        System.halt(1)
    end
  end
end
