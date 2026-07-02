defmodule LRP.Plugin.Registry do
  @moduledoc """
  LRP Eklenti Kayıt Defteri ve Bootstrapper'ı.
  Uygulama genelinde yüklenmiş tüm eklenti modüllerini dinamik olarak keşfeder
  ve veritabanına `provider` olarak kaydeder.
  """

  alias LRP.Capability.Manager, as: CapManager
  alias LRP.{Repo, Capability, Provider}
  import Ecto.Query

  @doc """
  Çalışma zamanında yüklenmiş olan ve `LRP.Plugin` arayüzünü uygulayan tüm modülleri keşfeder.
  """
  @spec discover_plugins() :: [module()]
  def discover_plugins do
    # Yüklenmiş tüm application modüllerini tara
    for {:ok, modules} <- Enum.map(Application.loaded_applications(), fn {app, _, _} -> :application.get_key(app, :modules) end),
        mod <- modules,
        implement_plugin?(mod) do
      mod
    end
    |> Enum.uniq()
  end

  @doc """
  Keşfedilen tüm eklentileri belirli bir tenant için sisteme otomatik kaydeder (bootstrap).
  Eğer eklentinin ait olduğu capability yoksa, önce capability'yi oluşturur.
  """
  @spec register_all(binary()) :: {:ok, [Provider.t()]} | {:error, term()}
  def register_all(tenant_id) do
    plugins = discover_plugins()

    results =
      for plugin <- plugins do
        meta = plugin.plugin_metadata()
        caps = plugin.supported_capabilities()

        for cap_type <- caps do
          # 1. Capability'nin varlığını kontrol et, yoksa ekle
          cap =
            case Repo.get_by(Capability, tenant_id: tenant_id, capability_type: cap_type) do
              nil ->
                _schema = plugin.config_schema(cap_type)
                {:ok, new_cap} = CapManager.create_capability(tenant_id, cap_type,
                  interface_contract: %{},
                  description: "#{cap_type} capability defined by plugin #{meta.name} (v#{meta.version})"
                )
                new_cap
              existing ->
                existing
            end

          # 2. Provider'ın varlığını kontrol et (module bazlı)
          ref_module = inspect(plugin)
          
          # Mevcut provider'ları tara
          existing_prov =
            Repo.one(
              from(p in Provider,
                where: p.capability_id == ^cap.id and p.provider_type == "elixir_module"
              )
            )
            # JSON serialization uyumluluğu için string modul ismini kontrol et
            |> case do
              nil -> nil
              prov ->
                if Map.get(prov.provider_ref, "module") == ref_module or Map.get(prov.provider_ref, :module) == plugin do
                  prov
                else
                  nil
                end
            end

          if is_nil(existing_prov) do
            {:ok, new_prov} = CapManager.add_provider(cap.id, "elixir_module",
              provider_ref: %{module: plugin},
              version: meta.version,
              status: "standby",
              description: meta.description
            )
            new_prov
          else
            existing_prov
          end
        end
      end
      |> List.flatten()

    {:ok, results}
  end

  # Eklentinin LRP.Plugin behaviour'ını uygulayıp uygulamadığını kontrol eder
  defp implement_plugin?(mod) do
    Code.ensure_loaded?(mod) and
      function_exported?(mod, :plugin_metadata, 0) and
      function_exported?(mod, :supported_capabilities, 0) and
      function_exported?(mod, :config_schema, 1) and
      function_exported?(mod, :validate_config, 2)
  end
end
