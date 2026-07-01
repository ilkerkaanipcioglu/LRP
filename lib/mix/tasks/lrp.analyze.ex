defmodule Mix.Tasks.Lrp.Analyze do
  use Mix.Task
  alias LRP.CliHelpers, as: H

  @shortdoc "Kaynak kodu analiz eder, LRP Object Graph oluşturur [--source <path|url>]"

  @moduledoc """
  Bir Elixir projesini (local path veya GitHub URL) analiz eder:
    - Modülleri OBJECT(type: "Module") olarak yazar
    - Bağımlılıkları RELATIONSHIP olarak yazar
    - LRP uyumluluk skorunu hesaplar (0–100)
    - Geliştirme önerilerini PROCESS_TASK olarak oluşturur

  ## Kullanım

      mix lrp.analyze --source /path/to/project
      mix lrp.analyze --source https://github.com/user/repo
      mix lrp.analyze --source /path/to/project --tenant <id>
      mix lrp.analyze --source /path/to/project --dry-run
      mix lrp.analyze --source /path/to/project --json

  ## Seçenekler

      --source    Analiz edilecek kaynak (zorunlu)
      --tenant    Tenant ID (yoksa demo seed tenant'ı kullanılır)
      --dry-run   DB'ye yazmadan sadece analiz et
      --json      MCP/agent için JSON çıktı

  ## LRP Uyumluluk Skoru

  Değerlendirilen kriterler:
    - Event emit (LRP.log_event çağrıları)
    - idempotency_key kullanımı
    - Actor takibi (actor_id / user_id)
    - Audit logging
    - @moduledoc varlığı
    - Ecto entegrasyonu
  """

  @switches [source: :string, tenant: :string, dry_run: :boolean, json: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    source    = Keyword.get(opts, :source)
    json_mode = Keyword.get(opts, :json, false)
    dry_run   = Keyword.get(opts, :dry_run, false)

    unless source do
      IO.puts(H.red("❌ --source gerekli"))
      IO.puts("   Örnek: mix lrp.analyze --source /path/to/project")
      System.halt(1)
    end

    H.start_app()

    unless json_mode do
      H.banner("LRP — Kaynak Analizi")
      IO.puts("  Kaynak  : #{H.cyan(source)}")
      IO.puts("  Mod     : #{if dry_run, do: H.yellow("dry-run"), else: H.green("kalıcı")}")
      IO.puts("")
    end

    tenant_id = resolve_tenant(opts, json_mode)

    unless json_mode, do: IO.puts("  #{H.dim("Ayrıştırılıyor...")} ")

    case LRP.Analyzer.analyze(source, tenant_id: tenant_id, dry_run: dry_run) do
      {:ok, result} ->
        if json_mode do
          H.json_output(%{
            source:        result.source,
            language:      result.language,
            lrp_score:     result.score.total,
            score_breakdown: result.score.breakdown,
            stats:         result.stats,
            modules_found: length(result.modules),
            tasks_created: length(result.tasks),
            dry_run:       dry_run
          })
        else
          print_result(result, dry_run)
        end

      {:error, reason} ->
        IO.puts(H.red("❌ Analiz başarısız: #{reason}"))
        System.halt(1)
    end
  end

  # ─── Çıktı ─────────────────────────────────────────────────────────────────

  defp print_result(result, dry_run) do
    score = result.score.total

    IO.puts("  #{H.bold("Analiz Tamamlandı")}")
    IO.puts("")

    # Özet istatistikler
    H.table(
      ["Metrik", "Değer"],
      [
        ["Dil",              result.language],
        ["Dosya sayısı",     to_string(result.stats.files)],
        ["Modül sayısı",     to_string(result.stats.modules)],
        ["Fonksiyon sayısı", to_string(result.stats.functions)],
        ["LRP Skoru",        score_display(score)]
      ]
    )

    # Skor detayı
    IO.puts(H.bold("  LRP Uyumluluk Skoru: #{score_display(score)}/100"))
    IO.puts("")

    breakdown = result.score.breakdown
    IO.puts("  Kriter detayı:")
    Enum.each(breakdown, fn {k, v} ->
      bar = progress_bar(v)
      IO.puts("    #{String.pad_trailing(to_string(k), 18)} #{bar} %#{v}")
    end)

    IO.puts("")

    if length(result.tasks) > 0 do
      IO.puts(H.bold("  Oluşturulan Görevler (#{length(result.tasks)}):"))
      IO.puts("")
      H.table(
        ["Görev", "Öncelik", "Durum"],
        Enum.map(result.tasks, fn t ->
          [H.truncate(t.name, 40), priority_label(t.priority), H.yellow(t.status)]
        end)
      )
      unless dry_run do
        IO.puts("  #{H.dim("→ mix lrp.tasks --tenant " <> (result.tenant_id || "") <> " ile görüntüle")}")
      end
    else
      IO.puts(H.green("  ✅ Ek görev önerilmedi — proje iyi durumda!"))
    end

    IO.puts("")

    unless dry_run do
      IO.puts(H.dim("  Sonraki adımlar:"))
      IO.puts(H.dim("    mix lrp.tasks --tenant #{result.tenant_id || "..."}"))
      IO.puts(H.dim("    mix lrp.object list --tenant #{result.tenant_id || "..."} --type Module"))
    end

    IO.puts("")
  end

  defp score_display(score) when score >= 75, do: H.green("#{score}")
  defp score_display(score) when score >= 40, do: H.yellow("#{score}")
  defp score_display(score),                  do: H.red("#{score}")

  defp progress_bar(value) do
    filled = round(value / 5)
    empty  = 20 - filled
    "[" <> String.duplicate("█", filled) <> String.duplicate("░", empty) <> "]"
  end

  defp priority_label("high"),   do: H.red("HIGH")
  defp priority_label("medium"), do: H.yellow("MEDIUM")
  defp priority_label("low"),    do: H.dim("LOW")
  defp priority_label(other),    do: other

  # ─── Tenant Çözümleme ───────────────────────────────────────────────────────

  defp resolve_tenant(opts, json_mode) do
    case Keyword.get(opts, :tenant) do
      nil ->
        tenants = LRP.list_tenants()
        case tenants do
          [t | _] ->
            unless json_mode, do: IO.puts("  Tenant  : #{H.dim(t.name)} (#{H.dim(String.slice(t.id, 0, 8))}...)")
            t.id
          [] ->
            unless json_mode, do: IO.puts(H.yellow("  ⚠  Tenant yok, demo seed çalıştırılıyor..."))
            Mix.Task.run("lrp.seed", ["--quiet"])
            List.first(LRP.list_tenants()).id
        end
      id -> id
    end
  end
end
