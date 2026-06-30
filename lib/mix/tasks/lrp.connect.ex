defmodule Mix.Tasks.Lrp.Connect do
  use Mix.Task

  @shortdoc "Bir GitHub reposunu LRP'ye bağlar ve domain entity'lerini keşfeder"

  @moduledoc """
  LRP Source Connector — GitHub Repo Bağlama Demo

  ## Kullanım

      mix lrp.connect <github_url> [--label "Etiket"] [--token ghp_xxx]

  ## Örnekler

      # LRP'nin kendi reposunu kendine bağla
      mix lrp.connect https://github.com/ilkerkaanipcioglu/LRP

      # Özel etiketle
      mix lrp.connect https://github.com/ilkerkaanipcioglu/LRP --label "LRP Self-Connect"

      # Private repo için token ile
      mix lrp.connect https://github.com/user/private-repo --token ghp_xxxxxxxxxxxx
  """

  @switches [label: :string, token: :string]

  def run(args) do
    # Uygulamayı başlat (DB bağlantısı için)
    Mix.Task.run("app.start")

    {opts, [repo_url | _], _} = OptionParser.parse(args, switches: @switches)

    label = Keyword.get(opts, :label, nil)
    token = Keyword.get(opts, :token, System.get_env("LRP_GITHUB_TOKEN"))

    IO.puts("""
    \n╔══════════════════════════════════════════════════════╗
    ║          LRP Source Connector — GitHub               ║
    ╚══════════════════════════════════════════════════════╝
    """)

    IO.puts("🔗 Bağlanıyor: #{repo_url}")
    IO.puts("🏷  Etiket   : #{label || "(repo adı kullanılacak)"}")
    IO.puts("🔑 Token    : #{if token, do: "✅ var", else: "❌ yok (public repo)"}")
    IO.puts("")

    # Demo tenant oluştur (gerçek kullanımda var olan tenant seçilir)
    {:ok, tenant} = LRP.create_tenant(%{name: "Demo Tenant — #{Date.utc_today()}"})

    IO.puts("⏳ GitHub API sorgulanıyor...\n")

    case LRP.SourceConnector.connect(tenant.id, repo_url: repo_url, token: token, label: label) do
      {:ok, %{source_system: sys, entities: entities, event: event, stats: stats}} ->
        IO.puts("""
        ✅ Bağlantı başarılı!
        ────────────────────────────────────────
        📦 Sistem     : #{sys.name}
        🌐 Dil        : #{stats.language || "Karışık"}
        📁 Dosya      : #{stats.files_scanned} dosya tarandı
        🔍 Entity     : #{stats.entities_found} varlık keşfedildi
        📋 Event ID   : #{event.id}
        ────────────────────────────────────────
        """)

        if length(entities) > 0 do
          IO.puts("Keşfedilen Entity'ler:")
          entities
          |> Enum.each(fn e ->
            src_type = if e.metadata["source_type"] == "content_parse", do: "📄", else: "📁"
            IO.puts("  #{src_type} #{e.name} (#{e.metadata["language"]}) ← #{e.metadata["source_file"]}")
          end)
        else
          IO.puts("ℹ️  Tanınan dosya pattern'ı bulunamadı.")
          IO.puts("   Migration, model veya schema dosyaları var mı?")
        end

        IO.puts("""

        ────────────────────────────────────────
        Sonraki adım:
          1. Keşfedilen entity'leri LRP Object tiplerine map et
          2. E-posta veya talimatlarla yeni sistemi inşa et

        Object ID: #{sys.id}
        """)

      {:error, reason} ->
        IO.puts("❌ Hata: #{reason}")
        System.halt(1)
    end
  end
end
