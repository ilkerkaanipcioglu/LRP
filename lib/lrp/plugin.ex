defmodule LRP.Plugin do
  @moduledoc """
  LRP Eklentileri (Plugins) için ortak davranış (behaviour) tanımı.
  Her eklenti bir veya birden fazla capability sözleşmesini gerçekler.
  """

  @type metadata :: %{
    name: String.t(),
    version: String.t(),
    author: String.t(),
    description: String.t()
  }

  @doc """
  Eklentinin adı, versiyonu ve açıklaması gibi temel bilgileri döner.
  """
  @callback plugin_metadata() :: metadata()

  @doc """
  Bu eklentinin desteklediği (gerçekleştirdiği) capability türlerini listeler.
  Örneğin: `["file_storage", "email_delivery"]`
  """
  @callback supported_capabilities() :: [String.t()]

  @doc """
  Verilen capability türü için gereken konfigürasyon şemasını döner.
  """
  @callback config_schema(capability_type :: String.t()) :: map()

  @doc """
  Verilen capability türü ve konfigürasyon verisini doğrular.
  `{:ok, validated_config}` veya `{:error, reason}` döner.
  """
  @callback validate_config(capability_type :: String.t(), config :: map()) ::
              {:ok, map()} | {:error, String.t()}
end
