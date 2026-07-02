defmodule LRP.Plugins.LocalStorage do
  @behaviour LRP.Plugin

  @impl true
  def plugin_metadata do
    %{
      name: "Local Disk File Storage",
      version: "1.0.0",
      author: "LRP Core Team",
      description: "Dosyaları yerel disk bölümlerinde depolar ve yönetir."
    }
  end

  @impl true
  def supported_capabilities do
    ["file_storage"]
  end

  @impl true
  def config_schema("file_storage") do
    %{
      "type" => "object",
      "properties" => %{
        "root_path" => %{"type" => "string", "description" => "Dosyaların yazılacağı kök dizin yolu."}
      },
      "required" => ["root_path"]
    }
  end

  @impl true
  def validate_config("file_storage", config) do
    root_path = Map.get(config, "root_path") || Map.get(config, :root_path)

    if is_binary(root_path) and String.length(root_path) > 0 do
      {:ok, %{root_path: root_path}}
    else
      {:error, "Konfigürasyonda geçerli bir 'root_path' belirtilmelidir."}
    end
  end

  # ─── Capability Interface Contracts ─────────────────────────────────────────

  @doc """
  Dosyayı diske kaydeder.
  """
  def upload_file(config, file_name, file_binary) do
    case validate_config("file_storage", config) do
      {:ok, validated} ->
        dest_path = Path.join(validated.root_path, file_name)
        Path.dirname(dest_path) |> File.mkdir_p!()
        
        case File.write(dest_path, file_binary) do
          :ok -> {:ok, dest_path}
          {:error, reason} -> {:error, "Dosya yazma hatası: #{reason}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Dosyayı diskten siler.
  """
  def delete_file(config, file_name) do
    case validate_config("file_storage", config) do
      {:ok, validated} ->
        filepath = Path.join(validated.root_path, file_name)
        case File.rm(filepath) do
          :ok -> :ok
          {:error, :enoent} -> :ok # Bulunamadıysa silinmiş kabul et
          {:error, reason} -> {:error, "Dosya silme hatası: #{reason}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
