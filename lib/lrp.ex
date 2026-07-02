defmodule LRP do
  @moduledoc """
  Core LRP (Lightweight Resource Planning) Engine API.
  Object Graph, Event Stream, Agent-Native Explainability, Policies, and Git-like Versioning.
  """

  import Ecto.Query
  alias LRP.Repo
  alias LRP.{Tenant, Actor, Object, Item, Relationship, Event, Policy, ProcessTask, Version}
  alias LRP.{AgentContext, AgentCapability}
  alias LRP.{Ledger, Journal, JournalLine, FiscalPeriod}
  alias LRP.{Connector, EventSubscription, PostingRule}

  # ─── Tenant API ─────────────────────────────────────────────────────────────
  def create_tenant(attrs) do
    %Tenant{} |> Tenant.changeset(attrs) |> Repo.insert()
  end

  # ─── Actor API ──────────────────────────────────────────────────────────────
  def create_actor(attrs) do
    %Actor{} |> Actor.changeset(attrs) |> Repo.insert()
  end

  # ─── Object API ─────────────────────────────────────────────────────────────
  def create_object(attrs) do
    case %Object{} |> Object.changeset(attrs) |> Repo.insert() do
      {:ok, object} ->
        LRP.ReadModel.trigger_async_sync(object.id)
        {:ok, object}
      error ->
        error
    end
  end

  def get_object(id), do: Repo.get(Object, id)

  def get_object_with_items(id) do
    Object
    |> where(id: ^id)
    |> preload([:items])
    |> Repo.one()
  end

  def update_object(%Object{} = object, attrs) do
    case object |> Object.changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        LRP.ReadModel.trigger_async_sync(updated.id)
        {:ok, updated}
      error ->
        error
    end
  end

  # ─── Item API ───────────────────────────────────────────────────────────────
  def create_item(attrs) do
    case %Item{} |> Item.changeset(attrs) |> Repo.insert() do
      {:ok, item} ->
        LRP.ReadModel.trigger_async_sync(item.object_id)
        {:ok, item}
      error ->
        error
    end
  end

  # ─── Relationships API ──────────────────────────────────────────────────────
  def relate(from_entity, from_id, to_entity, to_id, relationship_type) do
    attrs = %{
      from_entity: to_string(from_entity),
      from_id: from_id,
      to_entity: to_string(to_entity),
      to_id: to_id,
      relationship_type: relationship_type,
      valid_from: DateTime.utc_now()
    }
    case %Relationship{} |> Relationship.changeset(attrs) |> Repo.insert() do
      {:ok, rel} ->
        if to_string(from_entity) == "Object", do: LRP.ReadModel.trigger_async_sync(from_id)
        if to_string(to_entity) == "Object", do: LRP.ReadModel.trigger_async_sync(to_id)
        {:ok, rel}
      error ->
        error
    end
  end

  def list_relationships(from_entity, from_id, relationship_type \\ nil) do
    query =
      from(r in Relationship,
        where: r.from_entity == ^to_string(from_entity) and r.from_id == ^from_id
      )

    query =
      if relationship_type do
        from(r in query, where: r.relationship_type == ^relationship_type)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Başlangıç nesnesinden (from_id) yola çıkarak, belirli bir hedef tipteki (target_type) 
  ilişkili tüm nesneleri (Objects) getirir. İlişki yönü gözetmeksizin veya gözeterek çalışabilir.
  """
  def get_related_objects(from_entity, from_id, target_type) do
    # Direct ilişkiler: from_id -> to_id
    from_rels = 
      Relationship
      |> where(from_entity: ^to_string(from_entity), from_id: ^from_id, to_entity: ^to_string(target_type))
      |> select([r], r.to_id)
      |> Repo.all()

    # Ters ilişkiler: to_id -> from_id
    to_rels =
      Relationship
      |> where(to_entity: ^to_string(from_entity), to_id: ^from_id, from_entity: ^to_string(target_type))
      |> select([r], r.from_id)
      |> Repo.all()

    all_ids = Enum.uniq(from_rels ++ to_rels)

    Object
    |> where([o], o.id in ^all_ids)
    |> Repo.all()
  end

  @doc """
  İki nesne (from_id ve to_id) arasında maksimum derinliğe (max_depth) kadar 
  bir ilişki bağı/yolu (relationship path) olup olmadığını BFS algoritmasıyla kontrol eder.
  """
  def connected?(from_id, to_id, max_depth \\ 3) do
    bfs_check([[from_id]], to_id, MapSet.new([from_id]), 1, max_depth)
  end

  defp bfs_check([], _to_id, _visited, _current_depth, _max_depth), do: false
  defp bfs_check(_paths, _to_id, _visited, current_depth, max_depth) when current_depth > max_depth, do: false
  defp bfs_check(paths, to_id, visited, current_depth, max_depth) do
    next_paths =
      Enum.flat_map(paths, fn path ->
        last_node = List.last(path)
        
        # last_node'un bağlı olduğu tüm komşuları (hem from hem to yönünde) bul
        neighbors = get_all_neighbors(last_node)
        
        Enum.reduce(neighbors, [], fn neighbor, acc ->
          cond do
            neighbor == to_id ->
              # Hedefe ulaşıldı!
              throw(:found)
            
            MapSet.member?(visited, neighbor) ->
              acc
            
            true ->
              [path ++ [neighbor] | acc]
          end
        end)
      end)

    # Visited setini güncelle
    new_visited = Enum.reduce(next_paths, visited, fn path, acc ->
      MapSet.put(acc, List.last(path))
    end)

    bfs_check(next_paths, to_id, new_visited, current_depth + 1, max_depth)
  catch
    :found -> true
  end

  defp get_all_neighbors(node_id) do
    from_query =
      Relationship
      |> where(from_id: ^node_id)
      |> select([r], r.to_id)

    to_query =
      Relationship
      |> where(to_id: ^node_id)
      |> select([r], r.from_id)

    Enum.uniq(Repo.all(from_query) ++ Repo.all(to_query))
  end


  # ─── Events API ─────────────────────────────────────────────────────────────
  # tier: "HOT" (RAM-only, ajan koordinasyonu) | "DURABLE" (DB'ye yazılır, default)
  # actor_confidence: NULL=insan, 0.0-1.0=ajan (düşük değer → ApprovalRequest tetikler)
  # idempotency_key: retry-safe, aynı event iki kez insert edilemez
  def log_event(attrs) do
    attrs = Map.put_new(attrs, :occurred_at, DateTime.utc_now())
    case %Event{} |> Event.changeset(attrs) |> Repo.insert() do
      {:ok, event} ->
        if event.event_type != "webhook_delivery_failed" do
          LRP.Connector.Dispatcher.dispatch(event)
          process_posting_rules(event)
        end
        {:ok, event}
      error ->
        error
    end
  end

  def get_event(id), do: Repo.get(Event, id)

  def update_event(%Event{} = event, attrs) do
    event |> Event.changeset(attrs) |> Repo.update()
  end

  # ─── Agent-Native: AGENT_CONTEXT API ────────────────────────────────────────
  # "Everything is explainable" — ajan kararlarının denetim kaydı
  def log_agent_context(attrs) do
    attrs = Map.put_new(attrs, :inserted_at, DateTime.utc_now())
    %AgentContext{} |> AgentContext.changeset(attrs) |> Repo.insert()
  end

  def get_agent_contexts(actor_id) do
    AgentContext
    |> where(actor_id: ^actor_id)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  # ─── Agent-Native: AGENT_CAPABILITY API (MCP Tool Registry) ─────────────────
  def register_capability(attrs) do
    %AgentCapability{} |> AgentCapability.changeset(attrs) |> Repo.insert()
  end

  def list_capabilities(actor_id) do
    AgentCapability
    |> where(actor_id: ^actor_id, is_active: true)
    |> Repo.all()
  end

  # ─── Git-like Versioning API ────────────────────────────────────────────────
  # actor_confidence: NULL=insan commit, 0.0-1.0=ajan commit
  # actor_confidence: NULL=insan commit, 0.0-1.0=ajan commit
  def commit_version(object_id, committed_by_actor_id, commit_message, opts \\ []) do
    actor_confidence = Keyword.get(opts, :actor_confidence, nil)
    compaction_threshold = Keyword.get(opts, :compaction_threshold, 50)

    case get_object_with_items(object_id) do
      nil ->
        {:error, :object_not_found}

      object ->
        latest_version = find_latest_version(object_id)

        parent_version_id = if latest_version, do: latest_version.id, else: nil

        snapshot = %{
          "name" => object.name,
          "status" => object.status,
          "metadata" => object.metadata,
          "items" =>
            Enum.map(object.items, fn item ->
              %{
                "name" => item.name,
                "quantity" => item.quantity,
                "unit_value" => item.unit_value,
                "currency" => item.currency,
                "status" => item.status,
                "metadata" => item.metadata
              }
            end)
        }

        # Decide whether to save full snapshot or delta (ADR-0002 JSON Patch)
        delta_count = if latest_version, do: count_deltas_since_last_full(latest_version), else: 0

        snapshot_field =
          cond do
            is_nil(latest_version) ->
              Map.merge(snapshot, %{"type" => "full", "data" => snapshot})

            delta_count >= compaction_threshold ->
              Map.merge(snapshot, %{"type" => "full", "data" => snapshot})

            true ->
              parent_snap = reconstruct_snapshot(latest_version)
              patch = LRP.JSONPatch.diff(parent_snap, snapshot)
              %{"type" => "delta", "patch" => patch}
          end

        attrs = %{
          object_id: object_id,
          parent_version_id: parent_version_id,
          commit_message: commit_message,
          committed_by_actor_id: committed_by_actor_id,
          committed_at: DateTime.utc_now(),
          object_snapshot: snapshot_field,
          actor_confidence: actor_confidence
        }

        %Version{} |> Version.changeset(attrs) |> Repo.insert()
    end
  end

  defp count_deltas_since_last_full(nil), do: 0
  defp count_deltas_since_last_full(version) do
    count_deltas_recursive(version, 0)
  end

  defp count_deltas_recursive(nil, acc), do: acc
  defp count_deltas_recursive(version, acc) do
    case Map.get(version.object_snapshot, "type") do
      "delta" ->
        parent = if version.parent_version_id, do: Repo.get(Version, version.parent_version_id), else: nil
        count_deltas_recursive(parent, acc + 1)
      _ ->
        acc
    end
  end

  defp find_latest_version(object_id) do
    versions = Repo.all(from(v in Version, where: v.object_id == ^object_id))
    case versions do
      [] -> nil
      [single] -> single
      list ->
        parent_ids = MapSet.new(Enum.map(list, & &1.parent_version_id))
        Enum.find(list, fn v -> !MapSet.member?(parent_ids, v.id) end)
    end
  end

  @doc """
  Reconstructs the full snapshot of an object for a specific version.
  """
  def reconstruct_version(version_id) do
    case Repo.get(Version, version_id) do
      nil -> nil
      version -> reconstruct_snapshot(version)
    end
  end

  defp reconstruct_snapshot(version) do
    case Map.get(version.object_snapshot, "type") do
      "full" ->
        Map.get(version.object_snapshot, "data")

      "delta" ->
        parent_version = Repo.get(Version, version.parent_version_id)
        parent_snap = reconstruct_snapshot(parent_version)
        LRP.JSONPatch.apply_patch(parent_snap, Map.get(version.object_snapshot, "patch"))

      _ ->
        # Fallback for legacy database entries
        version.object_snapshot
    end
  end

  def get_version_history(object_id) do
    Version
    |> where(object_id: ^object_id)
    |> order_by([desc: :committed_at, desc: :inserted_at])
    |> Repo.all()
  end

  # ─── ReBAC & Access Control API (ADR-0003) ──────────────────────────────────
  def check_permission(actor_id, relation, object_id) do
    LRP.Authorization.check_permission(actor_id, relation, object_id)
  end

  # ─── Policy & Authorization API ─────────────────────────────────────────────
  def create_policy(attrs) do
    %Policy{} |> Policy.changeset(attrs) |> Repo.insert()
  end

  def authorize(actor_id, resource_type, action) do
    query =
      from(p in Policy,
        where:
          p.actor_id == ^actor_id and
            (p.resource_type == ^resource_type or p.resource_type == "*") and
            (p.action == ^action or p.action == "*")
      )

    policies = Repo.all(query)
    has_deny = Enum.any?(policies, fn p -> p.effect == "deny" end)
    has_allow = Enum.any?(policies, fn p -> p.effect == "allow" end)

    cond do
      has_deny -> :deny
      has_allow -> :allow
      true -> :deny
    end
  end

  # ─── Process & Task API ─────────────────────────────────────────────────────
  def create_process_task(attrs) do
    %ProcessTask{} |> ProcessTask.changeset(attrs) |> Repo.insert()
  end

  def update_process_task(%ProcessTask{} = task, attrs) do
    task |> ProcessTask.changeset(attrs) |> Repo.update()
  end

  # ─── Tenant-Aware Safe Query APIs (Tier 4 Omurgası) ───────────────────────────
  def list_objects_by_tenant(tenant_id) do
    Object |> where(tenant_id: ^tenant_id) |> Repo.all()
  end

  def list_objects_by_tenant_and_type(tenant_id, type) do
    Object |> where(tenant_id: ^tenant_id, type: ^type) |> Repo.all()
  end

  def list_relationships_by_tenant(tenant_id) do
    # Relationships tablosunda doğrudan tenant_id bulunmadığı için 
    # to_id nesnesinin bu tenant'a ait olup olmadığını kontrol eden bir JOIN sorgusu kuruyoruz.
    from(r in Relationship,
      join: o in Object,
      on: r.to_id == o.id,
      where: o.tenant_id == ^tenant_id,
      select: r
    )
    |> Repo.all()
  end

  def list_events_by_tenant(tenant_id) do
    Event 
    |> where(tenant_id: ^tenant_id) 
    |> order_by([e], desc: e.occurred_at) 
    |> Repo.all()
  end

  def list_agent_contexts_by_tenant(tenant_id) do
    AgentContext 
    |> where(tenant_id: ^tenant_id) 
    |> order_by([c], desc: c.inserted_at) 
    |> Repo.all()
  end

  # ─── CLI / Dashboard API ────────────────────────────────────────────────────
  @doc "Tüm tabloların kayıt sayısını tek sorguda döner. mix lrp.status ve MCP için."
  def count_all do
    %{
      tenants:       Repo.aggregate(Tenant,       :count),
      actors:        Repo.aggregate(Actor,        :count),
      objects:       Repo.aggregate(Object,       :count),
      events:        Repo.aggregate(Event,        :count),
      relationships: Repo.aggregate(Relationship, :count),
      versions:      Repo.aggregate(Version,      :count),
      process_tasks: Repo.aggregate(ProcessTask,  :count),
      agent_contexts: Repo.aggregate(AgentContext, :count)
    }
  end

  @doc "Tüm tenant'ları döner."
  def list_tenants, do: Repo.all(Tenant)

  @doc "Bir tenant'a ait actor'ları döner."
  def list_actors_by_tenant(tenant_id) do
    Actor |> where(tenant_id: ^tenant_id) |> Repo.all()
  end

  @doc "ID ile tenant getirir."
  def get_tenant(id), do: Repo.get(Tenant, id)

  @doc "Bir tenant'a ait PROCESS_TASK sayısını duruma göre döner."
  def count_process_tasks_by_tenant(tenant_id, status \\ nil) do
    query = ProcessTask |> where(tenant_id: ^tenant_id)
    query = if status, do: query |> where(status: ^status), else: query
    Repo.aggregate(query, :count)
  end

  @doc "Son N event'i tenant bazında döner (CLI için)."
  def list_recent_events(tenant_id, limit \\ 20) do
    Event
    |> where(tenant_id: ^tenant_id)
    |> order_by([e], desc: e.occurred_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Tenant'a ait PROCESS_TASK'ları döner. status filtresi opsiyonel."
  def list_process_tasks_by_tenant(tenant_id, status \\ nil) do
    query = ProcessTask |> where(tenant_id: ^tenant_id)
    query = if status, do: query |> where(status: ^status), else: query
    query |> order_by([t], desc: t.inserted_at) |> Repo.all()
  end

  @doc "Bir process task'ı ID ile getirir."
  def get_process_task(id), do: Repo.get(ProcessTask, id)

  @doc "Tüm actor'ları döner."
  def list_actors, do: Repo.all(Actor)

  # ─── Ledger API (Sprint 4) ──────────────────────────────────────────────────

  @doc "Yeni bir Ledger (defter) oluşturur."
  def create_ledger(attrs) do
    %Ledger{} |> Ledger.changeset(attrs) |> Repo.insert()
  end

  @doc "Yeni bir Journal (yevmiye fişi) oluşturur."
  def create_journal(attrs) do
    %Journal{} |> Journal.changeset(attrs) |> Repo.insert()
  end

  @doc "Yeni bir JournalLine (yevmiye satırı) oluşturur."
  def create_journal_line(attrs) do
    %JournalLine{} |> JournalLine.changeset(attrs) |> Repo.insert()
  end

  @doc "Yeni bir FiscalPeriod (mali dönem) oluşturur."
  def create_fiscal_period(attrs) do
    %FiscalPeriod{} |> FiscalPeriod.changeset(attrs) |> Repo.insert()
  end

  @doc "Verilen bir tarihin o tenant ve ledger için açık olup olmadığını kontrol eder."
  def is_period_open?(tenant_id, ledger_id, %Date{} = date) do
    query =
      from(p in FiscalPeriod,
        where: p.tenant_id == ^tenant_id and
               p.ledger_id == ^ledger_id and
               p.period_start <= ^date and
               p.period_end >= ^date,
        select: p.status
      )

    case Repo.one(query) do
      "open" -> true
      _ -> false
    end
  end

  @doc """
  Bir Journal begesi ve buna bağlı satırları (journal_lines) veritabanına yazar.
  İşlemi bir transaction içinde gerçekleştirir ve dönem kilidini kontrol eder.
  """
  def post_journal(tenant_id, ledger_id, journal_attrs, lines) do
    posting_date = journal_attrs[:posting_date] || journal_attrs["posting_date"]

    date = case posting_date do
      %Date{} = d -> d
      str when is_binary(str) -> Date.from_iso8601!(str)
      _ -> Date.utc_today()
    end

    if is_period_open?(tenant_id, ledger_id, date) do
      Repo.transaction(fn ->
        attrs =
          journal_attrs
          |> Map.put(:tenant_id, tenant_id)
          |> Map.put(:ledger_id, ledger_id)
          |> Map.put(:posting_date, date)

        # Map veya String key uyumluluğu için
        attrs = if is_map(attrs), do: attrs, else: Map.new(attrs)

        {:ok, journal} =
          %Journal{}
          |> Journal.changeset(attrs)
          |> Repo.insert()

        inserted_lines =
          Enum.map(lines, fn line_attrs ->
            line_attrs =
              line_attrs
              |> Map.put(:journal_id, journal.id)
              # Decimal dönüşümleri
              |> Map.update(:debit, 0.0, &to_decimal/1)
              |> Map.update(:credit, 0.0, &to_decimal/1)

            {:ok, line} =
              %JournalLine{}
              |> JournalLine.changeset(line_attrs)
              |> Repo.insert()
            line
          end)

        %{journal: journal, lines: inserted_lines}
      end)
    else
      {:error, :fiscal_period_closed_or_missing}
    end
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(v) when is_float(v), do: Decimal.from_float(v)
  defp to_decimal(v) when is_integer(v), do: Decimal.new(v)
  defp to_decimal(v) when is_binary(v), do: Decimal.new(v)
  defp to_decimal(v), do: v

  # ─── Connector & Subscription API (ADR-0007) ────────────────────────────────

  @doc "Yeni bir Connector tanımlar."
  def create_connector(attrs) do
    %Connector{} |> Connector.changeset(attrs) |> Repo.insert()
  end

  @doc "Yeni bir EventSubscription (Webhook abonesi) oluşturur."
  def create_subscription(attrs) do
    %EventSubscription{} |> EventSubscription.changeset(attrs) |> Repo.insert()
  end

  @doc "Verilen event_type ile eşleşen aktif abonelikleri listeler."
  def list_active_subscriptions(tenant_id, event_type) do
    EventSubscription
    |> where(tenant_id: ^tenant_id, status: "active")
    |> Repo.all()
    |> Enum.filter(&match_event_pattern?(&1.event_type_pattern, event_type))
  end

  @doc """
  Basit glob pattern matching gerçekleştirir.
  Örnek:
    "invoice.*" matches "invoice.approved", "invoice.created"
    "*" matches everything
  """
  def match_event_pattern?("*", _), do: true
  def match_event_pattern?(pattern, event_type) do
    if String.contains?(pattern, "*") do
      regex_str =
        pattern
        |> Regex.escape()
        # Escaped yıldız karakterini Regex dot-all karakterine çevir
        |> String.replace("\\*", ".*")
      
      regex = Regex.compile!("^" <> regex_str <> "$")
      Regex.match?(regex, event_type)
    else
      pattern == event_type
    end
  end

  # ─── Posting Rules API (Sprint 5+ / MVP) ────────────────────────────────────

  @doc "Yeni bir yevmiye posting kuralı tanımlar."
  def create_posting_rule(attrs) do
    %PostingRule{} |> PostingRule.changeset(attrs) |> Repo.insert()
  end

  @doc """
  Bir Event'i alır, onunla eşleşen posting kuralları varsa otomatik olarak
  yevmiye kaydı (Journal) oluşturur.
  """
  def process_posting_rules(%Event{} = event) do
    rules =
      PostingRule
      |> where(tenant_id: ^event.tenant_id, event_type: ^event.event_type, status: "active")
      |> Repo.all()

    Enum.map(rules, fn rule ->
      payload = event.payload || %{}
      
      # amount_path string veya atom key olabilir
      amount_val = 
        case Map.get(payload, rule.amount_path) do
          nil ->
            try do
              Map.get(payload, String.to_existing_atom(rule.amount_path))
            rescue
              _ -> nil
            end
          val ->
            val
        end

      amount =
        case amount_val do
          nil -> 0.0
          val when is_number(val) -> val
          val when is_binary(val) ->
            # Para sembollerini temizle
            val
            |> String.replace(~r/[^\d.]/, "")
            |> Float.parse()
            |> case do
              {f, _} -> f
              _ -> 0.0
            end
          _ -> 0.0
        end

      if amount > 0.0 do
        journal_attrs = %{
          doc_date: Date.utc_today(),
          posting_date: Date.utc_today(),
          source_event_id: event.id
        }

        lines = [
          %{account_id: rule.debit_account, debit: amount, credit: 0.0},
          %{account_id: rule.credit_account, debit: 0.0, credit: amount}
        ]

        post_journal(event.tenant_id, rule.ledger_id, journal_attrs, lines)
      else
        {:error, :invalid_amount}
      end
    end)
  end
  # ─── CQRS Read Model API (ADR-0001) ──────────────────────────────────────────
  def list_read_objects(tenant_id, type \\ nil) do
    LRP.ReadModel.list_objects(tenant_id, type)
  end

  def sync_read_model(object_id) do
    LRP.ReadModel.sync_object(object_id)
  end

  # ─── Capability Execution Routing API (ADR-0004) ─────────────────────────────
  def execute_capability(tenant_id, capability_type, function_name, arguments) do
    LRP.Capability.Manager.execute_capability(tenant_id, capability_type, function_name, arguments)
  end
end

