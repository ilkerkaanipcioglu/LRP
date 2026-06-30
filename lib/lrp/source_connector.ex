defmodule LRP.SourceConnector do
  @moduledoc """
  LRP Source Connector — Eski sistemleri LRP'ye bağlar.

  GitHub reposunu analiz eder, domain entity'lerini keşfeder ve
  LRP Object Graph'ına aktarır. Kullanıcı bundan sonra gelen mailler
  ve yönlendirmelerle yeni LRP versiyonunu yavaş yavaş inşa eder.

  ## Akış
      connect(tenant_id, %{repo_url: "https://github.com/user/old-ecommerce"})
        → GitHub API: repo metadata
        → GitHub API: dosya ağacı
        → Entity extraction (migration, model, schema dosyalarından)
        → OBJECT "SourceSystem" (bağlanan repo)
        → N × OBJECT "EntityType" (keşfedilen varlıklar)
        → EVENT "source_connected"
        → RELATIONSHIP (SourceSystem → EntityType: "contains")
  """

  require Logger

  # Desteklenen dillere göre entity dosyası pattern'ları
  @entity_patterns [
    # Elixir/Phoenix migrations
    ~r{priv/repo/migrations/.*_create_(\w+)\.exs$},
    ~r{priv/repo/migrations/.*_add_.*_to_(\w+)\.exs$},
    # Rails migrations
    ~r{db/migrate/.*_create_(\w+)\.rb$},
    # Models/schemas (various languages)
    ~r{app/models/(\w+)\.rb$},
    ~r{lib/.*/(\w+)\.ex$},
    ~r{src/models/(\w+)\.(ts|js)$},
    ~r{src/entities/(\w+)\.(ts|js)$},
    # Prisma
    ~r{prisma/.*schema.*\.prisma$},
    # SQL
    ~r{schema\.sql$},
    ~r{database\.sql$}
  ]

  # Dosya içeriğinden tablo/entity ismi çıkarmak için pattern'lar
  @content_patterns [
    # Elixir Ecto migrations
    ~r/create table\(:(\w+)\)/,
    ~r/create table\("(\w+)"\)/,
    # Rails ActiveRecord
    ~r/create_table :(\w+)/,
    ~r/create_table "(\w+)"/,
    # Prisma
    ~r/model (\w+) \{/,
    # SQL
    ~r/CREATE TABLE (?:IF NOT EXISTS )?[`"]?(\w+)[`"]?/i,
    # TypeScript/Class decorators
    ~r/@Entity\(['"](\w+)['"]\)/,
    ~r/class (\w+)(?:Entity|Model|Schema)/
  ]

  @github_api "https://api.github.com"

  @doc """
  Bir GitHub reposunu LRP'ye bağlar.

  ## Parametreler
    - tenant_id: binary_id
    - opts:
      - :repo_url  — "https://github.com/owner/repo" (zorunlu)
      - :token     — GitHub PAT (private repo için, opsiyonel)
      - :label     — insan okunabilir isim (opsiyonel, repo adı default)

  ## Dönüş
    {:ok, %{source_system: object, entities: [objects], event: event, stats: map}}
  """
  def connect(tenant_id, opts) do
    repo_url  = Keyword.fetch!(opts, :repo_url)
    token     = Keyword.get(opts, :token)
    label     = Keyword.get(opts, :label)

    with {:ok, {owner, repo}} <- parse_repo_url(repo_url),
         {:ok, repo_meta}     <- fetch_repo_meta(owner, repo, token),
         {:ok, file_tree}     <- fetch_file_tree(owner, repo, token),
         {:ok, entities}      <- extract_entities(owner, repo, file_tree, token) do

      system_label = label || repo_meta["full_name"]

      # Tüm LRP yazımları tek transaction'da
      result = LRP.Repo.transaction(fn ->

        # 1. SourceSystem OBJECT — bağlanan repo
        {:ok, source_system} = LRP.create_object(%{
          tenant_id: tenant_id,
          type:      "SourceSystem",
          name:      system_label,
          status:    "active",
          metadata:  %{
            "repo_url"         => repo_url,
            "owner"            => owner,
            "repo"             => repo,
            "language"         => repo_meta["language"],
            "description"      => repo_meta["description"],
            "default_branch"   => repo_meta["default_branch"],
            "stars"            => repo_meta["stargazers_count"],
            "last_pushed_at"   => repo_meta["pushed_at"],
            "entities_found"   => length(entities),
            "connected_at"     => DateTime.to_iso8601(DateTime.utc_now())
          }
        })

        # 2. EntityType OBJECT'leri — keşfedilen varlıklar
        entity_objects =
          entities
          |> Enum.uniq_by(& &1.name)
          |> Enum.map(fn entity ->
            {:ok, obj} = LRP.create_object(%{
              tenant_id: tenant_id,
              type:      "EntityType",
              name:      entity.name,
              status:    "discovered",
              metadata:  %{
                "source_file"  => entity.source_file,
                "source_type"  => entity.source_type,
                "language"     => entity.language,
                "mapped_to"    => nil   # Kullanıcı sonradan LRP Object type'ına map eder
              }
            })
            {:ok, _} = LRP.relate("SourceSystem", source_system.id, "EntityType", obj.id, "contains")
            obj
          end)

        # 3. EVENT — bağlantı kaydı (idempotency_key: repo + tarih)
        # on_conflict: :nothing → aynı gün tekrar bağlanılırsa mevcut event korunur
        idempotency_key = "source_connected:#{owner}/#{repo}:#{Date.utc_today()}"
        event_attrs = %{
          tenant_id:       tenant_id,
          event_type:      "source_connected",
          source:          "github",
          tier:            "DURABLE",
          idempotency_key: idempotency_key,
          occurred_at:     DateTime.utc_now(),
          payload: %{
            "repo_url"         => repo_url,
            "owner"            => owner,
            "repo"             => repo,
            "language"         => repo_meta["language"],
            "entities_found"   => length(entities),
            "entity_names"     => Enum.map(entity_objects, & &1.name)
          }
        }

        import Ecto.Query
        event =
          case LRP.Repo.insert(LRP.Event.changeset(%LRP.Event{}, event_attrs),
                 on_conflict: :nothing,
                 conflict_target: :idempotency_key
               ) do
            {:ok, %LRP.Event{id: nil}} ->
              # Conflict → mevcut event'i getir
              LRP.Repo.one!(from(e in LRP.Event, where: e.idempotency_key == ^idempotency_key))
            {:ok, ev} ->
              ev
          end


        {:ok, _} = LRP.relate("Event", event.id, "SourceSystem", source_system.id, "triggered")

        %{
          source_system: source_system,
          entities:      entity_objects,
          event:         event,
          stats: %{
            files_scanned:   length(file_tree),
            entities_found:  length(entity_objects),
            language:        repo_meta["language"]
          }
        }
      end)

      result
    end
  end

  # ─── GitHub API ─────────────────────────────────────────────────────────────

  defp parse_repo_url(url) do
    case Regex.run(~r{github\.com/([^/]+)/([^/]+?)(?:\.git)?$}, url) do
      [_, owner, repo] -> {:ok, {owner, repo}}
      _                -> {:error, "Geçersiz GitHub URL: #{url}"}
    end
  end

  defp fetch_repo_meta(owner, repo, token) do
    headers = build_headers(token)
    url = "#{@github_api}/repos/#{owner}/#{repo}"

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %{status: 404}} ->
        {:error, "Repo bulunamadı: #{owner}/#{repo}"}
      {:ok, %{status: 403}} ->
        {:error, "Erişim reddedildi. Private repo için --token kullanın."}
      {:ok, %{status: status}} ->
        {:error, "GitHub API hatası: #{status}"}
      {:error, reason} ->
        {:error, "HTTP hatası: #{inspect(reason)}"}
    end
  end

  defp fetch_file_tree(owner, repo, token) do
    headers = build_headers(token)
    url = "#{@github_api}/repos/#{owner}/#{repo}/git/trees/HEAD?recursive=1"

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"tree" => tree}}} ->
        paths = tree |> Enum.filter(&(&1["type"] == "blob")) |> Enum.map(&(&1["path"]))
        {:ok, paths}
      {:ok, %{status: 409}} ->
        # Boş repo
        {:ok, []}
      {:ok, %{status: status}} ->
        {:error, "File tree alınamadı: #{status}"}
      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp build_headers(nil),   do: [{"Accept", "application/vnd.github+json"}, {"X-GitHub-Api-Version", "2022-11-28"}]
  defp build_headers(token), do: [{"Authorization", "Bearer #{token}"} | build_headers(nil)]

  # ─── Entity Extraction ──────────────────────────────────────────────────────

  defp extract_entities(owner, repo, file_paths, token) do
    entities =
      file_paths
      |> Enum.flat_map(&extract_from_path/1)
      |> then(fn path_entities ->
           # Migration / schema dosyalarının içeriğini de parse et
           schema_files = find_schema_files(file_paths)
           content_entities = Enum.flat_map(schema_files, fn path ->
             case fetch_file_content(owner, repo, path, token) do
               {:ok, content} -> extract_from_content(content, path)
               _              -> []
             end
           end)
           path_entities ++ content_entities
         end)
      |> Enum.uniq_by(fn e -> String.downcase(e.name) end)
      |> Enum.reject(fn e -> e.name in ~w(schema migration index application) end)
      |> Enum.sort_by(& &1.name)

    {:ok, entities}
  end

  defp extract_from_path(path) do
    Enum.flat_map(@entity_patterns, fn pattern ->
      case Regex.run(pattern, path) do
        [_, name] ->
          [%{
            name:        camelize(name),
            source_file: path,
            source_type: :path_pattern,
            language:    detect_language(path)
          }]
        _ -> []
      end
    end)
  end

  defp find_schema_files(paths) do
    Enum.filter(paths, fn path ->
      String.contains?(path, "migration") or
      String.contains?(path, "schema") or
      String.ends_with?(path, ".prisma") or
      String.ends_with?(path, "schema.sql")
    end)
    |> Enum.take(30)  # API rate limit için max 30 dosya
  end

  defp fetch_file_content(owner, repo, path, token) do
    headers = build_headers(token)
    url = "#{@github_api}/repos/#{owner}/#{repo}/contents/#{path}"

    case Req.get(url, headers: headers) do
      {:ok, %{status: 200, body: %{"content" => content, "encoding" => "base64"}}} ->
        decoded = content |> String.replace("\n", "") |> Base.decode64!()
        {:ok, decoded}
      _ ->
        {:error, :not_found}
    end
  end

  defp extract_from_content(content, source_file) do
    Enum.flat_map(@content_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_ | captures] ->
        name = List.first(captures) || ""
        %{
          name:        camelize(name),
          source_file: source_file,
          source_type: :content_parse,
          language:    detect_language(source_file)
        }
      end)
    end)
  end

  defp detect_language(path) do
    cond do
      String.ends_with?(path, ".exs") or String.ends_with?(path, ".ex") -> "Elixir"
      String.ends_with?(path, ".rb")                                     -> "Ruby"
      String.ends_with?(path, ".py")                                     -> "Python"
      String.ends_with?(path, ".ts")                                     -> "TypeScript"
      String.ends_with?(path, ".js")                                     -> "JavaScript"
      String.ends_with?(path, ".prisma")                                 -> "Prisma"
      String.ends_with?(path, ".sql")                                    -> "SQL"
      true                                                               -> "Unknown"
    end
  end

  defp camelize(str) do
    str
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end
end
