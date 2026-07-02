defmodule LRP.Capability.Manager do
  @moduledoc """
  Capability / Provider / ProviderBinding hot-swap motoru. (ADR-0004)

  ## Temel Prensipler
  - CAPABILITY: "ne yapılıyor" — değişmez sözleşme
  - PROVIDER: "kim/nasıl yapıyor" — değiştirilebilir
  - PROVIDER_BINDING: "şu an kim aktif" — hot-swap buradan olur

  Çekirdek OBJECT/EVENT katmanı hiç değişmez — sadece PROVIDER_BINDING
  tablosunda bir foreign key değişir.

  ## Upgrade/Downgrade Akışı
  1. Yeni provider oluştur (status=standby)
  2. MigrationTracker başlat (shadow aşamasından)
  3. Kullanıcı hazır olduğunda bind/3 ile aktif provider'ı değiştir
  4. Eski provider status=deprecated olur (asla silinmez)
  """

  alias LRP.{Repo, Capability, Provider, ProviderBinding, MigrationTracker, Event}
  import Ecto.Query

  # ── Capability Yönetimi ───────────────────────────────────────────────────────

  @doc """
  Yeni bir capability tanımlar.

  ## Parametreler
  - `tenant_id`        — tenant UUID
  - `capability_type`  — "email" | "slack" | "accounting" | "note_taking" | ...
  - `opts`             — [interface_contract:, description:]
  """
  @spec create_capability(binary(), String.t(), keyword()) ::
          {:ok, Capability.t()} | {:error, Ecto.Changeset.t()}
  def create_capability(tenant_id, capability_type, opts \\ []) do
    %Capability{}
    |> Capability.changeset(%{
      tenant_id:          tenant_id,
      capability_type:    capability_type,
      interface_contract: Keyword.get(opts, :interface_contract, %{}),
      description:        Keyword.get(opts, :description)
    })
    |> Repo.insert()
  end

  # ── Provider Yönetimi ─────────────────────────────────────────────────────────

  @doc """
  Bir capability'ye yeni provider ekler.

  ## provider_type değerleri (v1)
  - "internal_md"    — salt .md dosyası (tasarım modu, kod çalışmıyor)
  - "external_app"   — webhook/API ile dış uygulama (Gmail, Slack)
  - "elixir_module"  — yerel Elixir modülü
  - "agent"          — AI agent olarak sarılmış provider
  - "human"          — görev insana atanmış
  """
  @spec add_provider(binary(), String.t(), keyword()) ::
          {:ok, Provider.t()} | {:error, Ecto.Changeset.t()}
  def add_provider(capability_id, provider_type, opts \\ []) do
    cap = Repo.get!(Capability, capability_id)

    %Provider{}
    |> Provider.changeset(%{
      tenant_id:     cap.tenant_id,
      capability_id: capability_id,
      provider_type: provider_type,
      provider_ref:  Keyword.get(opts, :provider_ref, %{}),
      version:       Keyword.get(opts, :version),
      status:        Keyword.get(opts, :status, "standby"),
      description:   Keyword.get(opts, :description)
    })
    |> Repo.insert()
  end

  @doc """
  Bir capability'deki tüm provider'ları listeler.

  ## Filtreler
  - `status` — "active" | "standby" | "deprecated" | :all (varsayılan: :all)
  """
  @spec list_providers(binary(), keyword()) :: [Provider.t()]
  def list_providers(capability_id, opts \\ []) do
    status_filter = Keyword.get(opts, :status, :all)

    query =
      from(p in Provider,
        where: p.capability_id == ^capability_id,
        order_by: [desc: p.inserted_at]
      )

    query =
      if status_filter == :all do
        query
      else
        from(p in query, where: p.status == ^status_filter)
      end

    Repo.all(query)
  end

  # ── Hot-Swap: Bind / Upgrade / Downgrade ──────────────────────────────────────

  @doc """
  Bir capability için aktif provider'ı değiştirir (hot-swap).
  Eski provider asla silinmez — status=deprecated olarak bırakılır.

  Bir provider_swapped EVENT'i oluşturur (denetim için kritik).

  ## Parametreler
  - `capability_id`  — hangi capability
  - `new_provider_id` — aktif olacak provider
  - `actor_id`       — kararı veren actor (User veya Agent)
  - `opts`           — [notes:, idempotency_key:]
  """
  @spec bind(binary(), binary(), binary(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def bind(capability_id, new_provider_id, actor_id, opts \\ []) do
    Repo.transaction(fn ->
      cap      = Repo.get!(Capability, capability_id)
      new_prov = Repo.get!(Provider, new_provider_id)
      now      = DateTime.utc_now()
      ikey     = Keyword.get(opts, :idempotency_key,
                   "bind-#{capability_id}-#{new_provider_id}-#{System.system_time(:millisecond)}")

      # Validation if new provider is an Elixir module implementing Plugin behaviour
      if new_prov.provider_type == "elixir_module" do
        module_name = Map.get(new_prov.provider_ref, "module") || Map.get(new_prov.provider_ref, :module)
        module = resolve_module(module_name)

        if module && Code.ensure_loaded?(module) and function_exported?(module, :validate_config, 2) do
          case module.validate_config(cap.capability_type, new_prov.provider_ref) do
            {:ok, _validated} -> :ok
            {:error, reason} -> Repo.rollback("Configuration validation failed for plugin #{inspect(module)}: #{reason}")
          end
        end
      end

      # Mevcut binding'i bul
      old_binding = Repo.get_by(ProviderBinding,
        tenant_id: cap.tenant_id,
        capability_id: capability_id
      )

      # Eski provider'ı deprecated yap
      if old_binding do
        old_prov = Repo.get!(Provider, old_binding.active_provider_id)
        old_prov
        |> Provider.changeset(%{status: "deprecated"})
        |> Repo.update!()
      end

      # Yeni provider'ı active yap
      new_prov
      |> Provider.changeset(%{status: "active"})
      |> Repo.update!()

      # Binding'i upsert et
      new_binding =
        case old_binding do
          nil ->
            %ProviderBinding{}
            |> ProviderBinding.changeset(%{
              tenant_id:          cap.tenant_id,
              capability_id:      capability_id,
              active_provider_id: new_provider_id,
              bound_by_actor_id:  actor_id,
              bound_at:           now,
              notes:              Keyword.get(opts, :notes)
            })
            |> Repo.insert!()

          existing ->
            existing
            |> ProviderBinding.changeset(%{
              active_provider_id: new_provider_id,
              bound_by_actor_id:  actor_id,
              bound_at:           now,
              notes:              Keyword.get(opts, :notes)
            })
            |> Repo.update!()
        end

      # Denetim event'i
      %Event{}
      |> Event.changeset(%{
        tenant_id:       cap.tenant_id,
        event_type:      "provider_swapped",
        source:          "capability_manager",
        occurred_at:     now,
        payload:         %{
          capability_id:      capability_id,
          capability_type:    cap.capability_type,
          new_provider_id:    new_provider_id,
          new_provider_type:  new_prov.provider_type,
          old_provider_id:    old_binding && old_binding.active_provider_id,
          swapped_by_actor:   actor_id
        },
        tier:            "DURABLE",
        idempotency_key: ikey
      })
      |> Repo.insert!()

      %{binding: new_binding, capability: cap, provider: new_prov}
    end)
  end

  @doc """
  Mevcut provider'ı yükseltir: yeni provider ekler ve bind eder.
  Upgrade gerektiğinde kullanılır (örn. internal_md → Gmail).

  Arka planda MigrationTracker başlatır (shadow aşamasından).
  """
  @spec upgrade(binary(), String.t(), map(), binary(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def upgrade(capability_id, new_provider_type, provider_ref, actor_id, opts \\ []) do
    with {:ok, new_provider} <- add_provider(capability_id, new_provider_type,
                                  provider_ref: provider_ref,
                                  status: "standby",
                                  version: Keyword.get(opts, :version)),
         {:ok, bind_result} <- bind(capability_id, new_provider.id, actor_id, opts) do
      {:ok, Map.put(bind_result, :new_provider, new_provider)}
    end
  end

  @doc """
  Aktif provider'ı önceki provider'a geri döndürür (downgrade).
  Eski provider hiç silinmemiştir — status=deprecated olarak duruyordu.

  Veri kaybı olmaz çünkü provider asla silinmez.
  """
  @spec downgrade(binary(), binary(), binary(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def downgrade(capability_id, previous_provider_id, actor_id, opts \\ []) do
    # Önceki provider'ı active duruma getir ve bind et
    prev_prov = Repo.get!(Provider, previous_provider_id)

    prev_prov
    |> Provider.changeset(%{status: "active"})
    |> Repo.update!()

    bind(capability_id, previous_provider_id, actor_id,
      Keyword.merge(opts, [notes: "downgrade: #{Keyword.get(opts, :reason, "user_decision")}"]))
  end

  @doc """
  Aktif provider'ı döndürür. nil ise capability henüz bağlanmamış.
  """
  @spec active_provider(binary()) :: Provider.t() | nil
  def active_provider(capability_id) do
    case Repo.get_by(ProviderBinding, capability_id: capability_id) do
      nil -> nil
      binding -> Repo.get(Provider, binding.active_provider_id)
    end
  end

  # ── Execution Routing (ADR-0004) ──────────────────────────────────────────────

  @doc """
  Executes a function of a capability on the currently bound active provider.
  Routes the call dynamically depending on the provider type:
  - "elixir_module": Calls the configured Elixir module using `apply/3`.
  - "internal_md": Creates a suggested `ProcessTask` for a human and returns `{:error, {:manual_blueprint_required, task.id}}`.
  - "human": Creates a pending `ProcessTask` assigned to a human and returns `{:error, {:assigned_to_human, task.id}}`.
  - "external_app": Simulates triggering external API call, logs a routing Event, returns `{:ok, :dispatched}`.
  - "agent": Logs an coordination Event and returns `{:ok, :coordinated}`.
  """
  @spec execute_capability(binary(), String.t(), String.t(), list()) ::
          {:ok, term()} | {:error, term()}
  def execute_capability(tenant_id, capability_type, function_name, arguments) do
    case Repo.get_by(Capability, tenant_id: tenant_id, capability_type: capability_type) do
      nil ->
        {:error, :capability_not_found}

      cap ->
        case active_provider(cap.id) do
          nil ->
            {:error, :no_active_provider_bound}

          prov ->
            dispatch_execution(cap, prov, function_name, arguments)
        end
    end
  end

  defp dispatch_execution(_cap, %Provider{provider_type: "elixir_module"} = prov, function_name, arguments) do
    module_name = Map.get(prov.provider_ref, "module") || Map.get(prov.provider_ref, :module)
    module = resolve_module(module_name)
    
    cond do
      is_nil(module) ->
        {:error, :elixir_module_not_configured}

      true ->
        try do
          # Prepend provider_ref (config) to arguments if it is a Plugin implementing validate_config/2
          args =
            if Code.ensure_loaded?(module) and function_exported?(module, :validate_config, 2) do
              [prov.provider_ref | arguments]
            else
              arguments
            end

          fun = String.to_existing_atom(function_name)
          {:ok, apply(module, fun, args)}
        rescue
          e ->
            {:error, {:execution_failed, inspect(e)}}
        end
    end
  end

  defp dispatch_execution(cap, %Provider{provider_type: "internal_md"} = prov, function_name, arguments) do
    obj_id = resolve_object_id(cap.tenant_id, arguments)
    
    {:ok, task} = LRP.create_process_task(%{
      tenant_id: cap.tenant_id,
      process_name: "Manual Blueprint Execution",
      name: "Execute #{cap.capability_type} -> #{function_name}",
      object_id: obj_id,
      state: "suggested",
      status: "pending",
      priority: "medium",
      metadata: %{
        "provider_id" => prov.id,
        "function" => function_name,
        "arguments" => inspect(arguments),
        "reason" => "Process is currently defined only as markdown design document (blueprint)."
      }
    })
    {:error, {:manual_blueprint_required, task.id}}
  end

  defp dispatch_execution(cap, %Provider{provider_type: "human"} = prov, function_name, arguments) do
    assigned_actor_id = Map.get(prov.provider_ref, "actor_id") || Map.get(prov.provider_ref, :actor_id)
    obj_id = resolve_object_id(cap.tenant_id, arguments)

    {:ok, task} = LRP.create_process_task(%{
      tenant_id: cap.tenant_id,
      process_name: "Human Action Workflow",
      name: "Perform #{cap.capability_type} -> #{function_name}",
      object_id: obj_id,
      state: "assigned",
      status: "pending",
      priority: "high",
      assigned_actor_id: assigned_actor_id,
      metadata: %{
        "provider_id" => prov.id,
        "function" => function_name,
        "arguments" => inspect(arguments)
      }
    })
    {:error, {:assigned_to_human, task.id}}
  end

  defp dispatch_execution(cap, %Provider{provider_type: "external_app"} = prov, function_name, arguments) do
    now = DateTime.utc_now()
    {:ok, _} = LRP.log_event(%{
      tenant_id: cap.tenant_id,
      event_type: "capability_externally_dispatched",
      source: "capability_manager",
      occurred_at: now,
      idempotency_key: "dispatch-#{cap.id}-#{function_name}-#{System.system_time(:microsecond)}",
      payload: %{
        "provider_id" => prov.id,
        "provider_type" => "external_app",
        "function" => function_name,
        "arguments" => inspect(arguments),
        "provider_ref" => prov.provider_ref
      }
    })
    {:ok, :dispatched}
  end

  defp dispatch_execution(cap, %Provider{provider_type: "agent"} = prov, function_name, arguments) do
    now = DateTime.utc_now()
    assigned_agent_id = Map.get(prov.provider_ref, "actor_id") || Map.get(prov.provider_ref, :actor_id)

    {:ok, _} = LRP.log_event(%{
      tenant_id: cap.tenant_id,
      event_type: "agent_coordination_requested",
      source: "capability_manager",
      occurred_at: now,
      idempotency_key: "agent-coord-#{cap.id}-#{function_name}-#{System.system_time(:microsecond)}",
      payload: %{
        "provider_id" => prov.id,
        "provider_type" => "agent",
        "agent_actor_id" => assigned_agent_id,
        "function" => function_name,
        "arguments" => inspect(arguments)
      }
    })
    {:ok, :coordinated}
  end

  defp resolve_object_id(tenant_id, arguments) do
    first_arg = List.first(arguments)
    
    cond do
      is_binary(first_arg) and valid_uuid?(first_arg) and Repo.exists?(from(o in LRP.Object, where: o.id == ^first_arg)) ->
        first_arg
        
      true ->
        {:ok, obj} = LRP.create_object(%{
          tenant_id: tenant_id,
          type: "ProcessExecution",
          name: "Capability Execution Context"
        })
        obj.id
    end
  end

  defp resolve_module(module_name) do
    cond do
      is_nil(module_name) -> nil
      is_atom(module_name) -> module_name
      is_binary(module_name) ->
        case String.starts_with?(module_name, "Elixir.") do
          true ->
            try do
              String.to_existing_atom(module_name)
            rescue
              _ -> nil
            end
          false ->
            try do
              String.to_existing_atom("Elixir." <> module_name)
            rescue
              _ -> nil
            end
        end
      true -> nil
    end
  end

  defp valid_uuid?(str) do
    case Ecto.UUID.cast(str) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
