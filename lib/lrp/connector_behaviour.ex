defmodule LRP.ConnectorBehaviour do
  @moduledoc """
  Standart Connector / Adapter Kontratı (ADR-0007).

  Her LRP Connector entegrasyonu (örn: GitHub, Slack, Email) bu behaviour'ı uygular.
  """

  @doc """
  Dış sistemden gelen ham olay verisini (raw event payload) standart LRP.Event payload formatına dönüştürür.
  """
  @callback transform(raw_event :: map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Connector'ın hedef dış sistemle olan bağlantı sağlığını kontrol eder.
  """
  @callback health_check(config :: map()) :: :ok | {:error, term()}
end
