defmodule LRP.Analyzer do
  @moduledoc """
  Bir kaynak sistemi (local path veya GitHub URL) analiz eder:
    1. Kaynak kodunu ayrıştırır (ElixirParser)
    2. Her modülü OBJECT(type: "Module") olarak LRP'ye yazar
    3. Bağımlılıkları RELATIONSHIP(type: "depends_on") olarak yazar
    4. LRP uyumluluk skoru hesaplar
    5. Geliştirme önerileri PROCESS_TASK olarak yazar

  Çıktı yapısı:
    %{
      tenant_id:      binary(),
      source:         String.t(),
      language:       String.t(),
      modules:        [map()],            # oluşturulan Object'ler
      relationships:  [map()],            # oluşturulan Relationship'ler
      tasks:          [map()],            # oluşturulan PROCESS_TASK'lar
      score:          %{total: float, breakdown: map()},
      stats:          %{files: int, modules: int, functions: int}
    }
  """

  alias LRP.CodeParser.ElixirParser
  alias LRP.CodeParser.PythonParser

  # ─── Ana Giriş ──────────────────────────────────────────────────────────────
  
  @doc """
  Kaynağı analiz eder ve sonuçları LRP'ye yazar.

  ## Seçenekler
    - `:tenant_id` (zorunlu) — hangi tenant altında oluşturulacak
    - `:actor_id`  (opsiyonel) — görevi kime atanacak (nil = tenant'ın ilk actor'ı)
    - `:dry_run`   (default: false) — DB'ye yazma, sadece analiz et
  """
  def analyze(source, opts \\ []) do
    tenant_id = Keyword.fetch!(opts, :tenant_id)
    dry_run   = Keyword.get(opts, :dry_run, false)

    with {:ok, modules, stats, language} <- fetch_and_parse(source),
         score                           <- compute_score(modules) do

      if dry_run do
        {:ok, %{
          tenant_id: tenant_id, source: source, language: language,
          modules: modules, relationships: [], tasks: [],
          score: score, stats: stats, dry_run: true
        }}
      else
        persist(tenant_id, source, language, modules, score, stats, opts)
      end
    end
  end

  # ─── Fetch & Parse ──────────────────────────────────────────────────────────

  defp fetch_and_parse(source) do
    cond do
      github_url?(source) -> parse_github(source)
      File.dir?(source)   -> parse_local(source)
      true -> {:error, "Kaynak tanınmadı: local path veya GitHub URL olmalı"}
    end
  end

  defp parse_local(path) do
    lang = detect_language(path)

    case lang do
      "Python" ->
        case PythonParser.parse_directory(path) do
          {:ok, modules} ->
            stats = %{
              files:     count_python_files(path),
              modules:   length(modules),
              functions: modules |> Enum.flat_map(& &1.functions) |> length()
            }
            {:ok, modules, stats, "Python"}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        case ElixirParser.parse_directory(path) do
          {:ok, modules} ->
            stats = %{
              files:     count_files(path),
              modules:   length(modules),
              functions: modules |> Enum.flat_map(& &1.functions) |> length()
            }
            {:ok, modules, stats, "Elixir"}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp detect_language(path) do
    py_files = Path.wildcard("#{path}/**/*.py") |> Enum.reject(&String.contains?(&1, "/venv/"))
    ex_files = Path.wildcard("#{path}/**/*.{ex,exs}") |> Enum.reject(&String.contains?(&1, "/deps/"))

    cond do
      length(py_files) > length(ex_files) -> "Python"
      true -> "Elixir"
    end
  end

  defp count_python_files(path) do
    Path.wildcard("#{path}/**/*.py")
    |> Enum.reject(&String.contains?(&1, "/venv/"))
    |> Enum.reject(&String.contains?(&1, "/.venv/"))
    |> Enum.reject(&String.contains?(&1, "/__pycache__/"))
    |> length()
  end

  defp parse_github(url) do
    # GitHub URL'den metadata çek — dosya içeriği için SourceConnector'ı genişletmek gerekir
    # Sprint 2'de: repo metadata + dosya listesi, Sprint 2.5'te tam dosya içeriği
    case LRP.SourceConnector.connect(nil, repo_url: url) do
      {:ok, %{stats: stats, entities: entities}} ->
        # SourceConnector entity'lerini modül formatına dönüştür
        modules = Enum.map(entities, fn e ->
          %{
            name: e.name, path: e.metadata["source_file"],
            functions: [], aliases: [], uses: [], imports: [],
            moduledoc: nil, has_broadway: false, has_ecto: false,
            has_genserver: false, line_count: 0
          }
        end)
        github_stats = %{
          files: stats.files_scanned,
          modules: length(modules),
          functions: 0  # GitHub URL'de tam AST yok
        }
        {:ok, modules, github_stats, stats.language || "Elixir"}

      {:error, reason} -> {:error, reason}
    end
  end

  defp github_url?(s) do
    String.starts_with?(s, "https://github.com/") or
    String.starts_with?(s, "http://github.com/")
  end

  defp count_files(path) do
    Path.wildcard("#{path}/**/*.{ex,exs}")
    |> Enum.reject(&String.contains?(&1, "/_build/"))
    |> Enum.reject(&String.contains?(&1, "/deps/"))
    |> length()
  end

  # ─── LRP Uyumluluk Skoru ────────────────────────────────────────────────────

  @doc """
  LRP uyumluluk skoru hesaplar (0.0 – 100.0).

  Kriterler:
    - event_emit      : EVENT üretiyor mu? (Broadway, callback, log_event pattern)
    - idempotency     : idempotency_key kullanıyor mu?
    - actor_tracking  : actor_id / user_id izleme var mı?
    - audit_logging   : Logger veya audit fonksiyon çağrısı var mı?
    - moduledoc       : @moduledoc yazılmış mı?
    - typespecs       : @spec anotas yonu var mı? (fonksiyon adlarından tahmin)
  """
  def compute_score(modules) when modules == [], do: %{total: 0.0, breakdown: %{}}

  def compute_score(modules) do
    all_fns   = modules |> Enum.flat_map(& &1.functions)
    all_uses  = modules |> Enum.flat_map(& &1.uses)
    has_docs  = modules |> Enum.count(& &1.moduledoc != nil)

    breakdown = %{
      event_emit:     score_criterion(modules, &has_event_pattern?/1),
      idempotency:    score_criterion(modules, &has_idempotency?/1),
      actor_tracking: score_criterion(modules, &has_actor_tracking?/1),
      audit_logging:  score_criterion(modules, &has_audit?/1),
      moduledoc:      if(has_docs > 0, do: min(has_docs / length(modules) * 100, 100), else: 0.0),
      ecto_usage:     if(Enum.any?(all_uses, &String.contains?(&1, "Ecto")), do: 50.0, else: 0.0)
    }

    _ = all_fns  # silence unused warning

    total = breakdown |> Map.values() |> Enum.sum() |> Kernel./(map_size(breakdown))

    %{total: Float.round(total, 1), breakdown: breakdown}
  end

  defp score_criterion(modules, fun) do
    matching = Enum.count(modules, fun)
    if length(modules) > 0, do: Float.round(matching / length(modules) * 100, 1), else: 0.0
  end

  defp has_event_pattern?(mod) do
    mod.has_broadway or
    Enum.any?(mod.functions, &String.starts_with?(&1, "log_event")) or
    Enum.any?(mod.functions, &String.starts_with?(&1, "emit_"))
  end

  defp has_idempotency?(mod) do
    Enum.any?(mod.functions, &String.contains?(&1, "idempotent")) or
    Enum.any?(mod.aliases, &String.contains?(&1, "Idempotent"))
  end

  defp has_actor_tracking?(mod) do
    Enum.any?(mod.functions, fn f ->
      String.contains?(f, "actor") or String.contains?(f, "user_id")
    end)
  end

  defp has_audit?(mod) do
    Enum.any?(mod.functions, fn f ->
      String.contains?(f, "audit") or String.contains?(f, "log_")
    end)
  end

  # ─── DB'ye Yazma ────────────────────────────────────────────────────────────

  defp persist(tenant_id, source, language, modules, score, stats, opts) do
    actor_id = resolve_actor(tenant_id, opts)

    # Kaynak sistemi OBJECT
    {:ok, source_obj} = LRP.create_object(%{
      tenant_id: tenant_id,
      type:      "SourceSystem",
      name:      Path.basename(source),
      status:    "analyzed",
      metadata: %{
        "source"     => source,
        "language"   => language,
        "score"      => score.total,
        "stats"      => stats,
        "analyzed_at" => DateTime.utc_now() |> to_string()
      }
    })

    # Her modül → OBJECT(type: "Module")
    module_objects =
      Enum.map(modules, fn mod ->
        {:ok, obj} = LRP.create_object(%{
          tenant_id: tenant_id,
          type:      "Module",
          name:      mod.name,
          status:    "discovered",
          metadata: %{
            "path"          => mod.path,
            "function_count" => length(mod.functions),
            "functions"     => Enum.take(mod.functions, 20),
            "aliases"       => mod.aliases,
            "uses"          => mod.uses,
            "line_count"    => mod.line_count,
            "has_broadway"  => mod.has_broadway,
            "has_ecto"      => mod.has_ecto,
            "has_genserver" => mod.has_genserver,
            "moduledoc"     => mod.moduledoc
          }
        })
        LRP.relate("SourceSystem", source_obj.id, "Module", obj.id, "contains")
        {mod.name, obj}
      end)

    name_to_id = Map.new(module_objects)

    # Dependency RELATIONSHIP'ler
    relationships =
      Enum.flat_map(modules, fn mod ->
        mod.aliases
        |> Enum.filter(&Map.has_key?(name_to_id, &1))
        |> Enum.map(fn dep ->
          from_obj = name_to_id[mod.name]
          to_obj   = name_to_id[dep]
          {:ok, rel} = LRP.relate("Module", from_obj.id, "Module", to_obj.id, "depends_on")
          rel
        end)
      end)

    # EVENT: analiz tamamlandı
    idempotency_key = "analyze:#{tenant_id}:#{source}:#{Date.utc_today()}"
    event_attrs = %{
      tenant_id:        tenant_id,
      event_type:       "source_analyzed",
      source:           "lrp_analyzer",
      tier:             "DURABLE",
      actor_confidence: 0.95,
      idempotency_key:  idempotency_key,
      occurred_at:      DateTime.utc_now(),
      payload: %{
        "source"         => source,
        "language"       => language,
        "module_count"   => length(modules),
        "lrp_score"      => score.total,
        "files_analyzed" => stats.files
      }
    }

    import Ecto.Query
    _event =
      case LRP.Repo.insert(LRP.Event.changeset(%LRP.Event{}, event_attrs),
             on_conflict: :nothing,
             conflict_target: :idempotency_key
           ) do
        {:ok, %LRP.Event{id: nil}} ->
          LRP.Repo.one!(from(e in LRP.Event, where: e.idempotency_key == ^idempotency_key))
        {:ok, ev} ->
          ev
      end

    # PROCESS_TASK'lar — iyileştirme önerileri
    tasks = generate_tasks(tenant_id, source_obj.id, actor_id, modules, score)

    {:ok, %{
      tenant_id:     tenant_id,
      source:        source,
      language:      language,
      source_object: source_obj,
      modules:       Enum.map(module_objects, fn {_, obj} -> obj end),
      relationships: relationships,
      tasks:         tasks,
      score:         score,
      stats:         stats
    }}
  end

  defp resolve_actor(tenant_id, opts) do
    case Keyword.get(opts, :actor_id) do
      nil ->
        case LRP.list_actors_by_tenant(tenant_id) do
          [first | _] -> first.id
          []          -> nil
        end
      id -> id
    end
  end

  # ─── PROCESS_TASK Üretimi ────────────────────────────────────────────────────

  defp generate_tasks(tenant_id, source_id, actor_id, modules, score) do
    suggestions = [
      {score.breakdown.event_emit < 50,
       "Event emit ekle",
       "Modüllerin %#{round(100 - score.breakdown.event_emit)}'i LRP.log_event çağrısı yapmıyor. " <>
       "Her önemli iş aksiyonunu EVENT olarak kayıt altına al.",
       "medium"},

      {score.breakdown.idempotency < 30,
       "idempotency_key ekle",
       "Retry-safe olmayan işlemler tespit edildi. " <>
       "Her write operasyonuna benzersiz idempotency_key ekle.",
       "high"},

      {score.breakdown.actor_tracking < 30,
       "Actor takibi ekle",
       "İşlemlerde actor_id / user_id izlenmiyor. " <>
       "Kim, neyi, ne zaman yaptı sorusu cevaplanamaz.",
       "medium"},

      {score.breakdown.moduledoc < 50,
       "Moduledoc eksik",
       "Modüllerin %#{round(100 - score.breakdown.moduledoc)}'inde @moduledoc yok. " <>
       "Agent sistemlerin modülü anlaması için dokümantasyon şart.",
       "low"},

      {length(modules) > 0 and score.total < 40,
       "LRP mimarisine geçiş planı",
       "LRP uyumluluk skoru #{score.total}/100. " <>
       "OBJECT/EVENT merkezli yeniden yapılanma için sprint planı önerilir.",
       "high"}
    ]

    suggestions
    |> Enum.filter(fn {condition, _, _, _} -> condition end)
    |> Enum.map(fn {_, name, desc, priority} ->
      {:ok, task} = LRP.create_process_task(%{
        tenant_id:         tenant_id,
        object_id:         source_id,
        assigned_actor_id: actor_id,
        process_name:      "LRP Code Compliance Analysis",
        name:              name,
        state:             "suggested",
        status:            "pending",
        priority:          priority,
        metadata:          %{"description" => desc, "source" => "lrp_analyzer"}
      })
      task
    end)
  end
end
