defmodule LRP.Connector.Dispatcher do
  @moduledoc """
  LRP Outbound Event Dispatcher (ADR-0007).

  Yeni bir LRP.Event oluşturulduğunda tetiklenir. Eşleşen webhook'lara
  asenkron HTTP POST istekleri gönderir. Causation depth limitiyle loop'ları engeller.
  """

  require Logger
  alias LRP.Event

  @doc """
  Olayı ilgili abonelere asenkron dağıtır.
  """
  def dispatch(%Event{} = event) do
    # Causation depth event payload içinde taşınır, varsayılan 0
    depth = Map.get(event.payload || %{}, "causation_depth", 0)

    subs = LRP.list_active_subscriptions(event.tenant_id, event.event_type)
    caller = self()

    Enum.each(subs, fn sub ->
      if depth < sub.max_causation_depth do
        Task.start(fn ->
          deliver(sub, event, depth, caller)
        end)
      else
        Logger.warning("[Dispatcher] Event #{event.id} causation depth limit exceeded: #{depth} >= #{sub.max_causation_depth}")
      end
    end)

    :ok
  end

  defp deliver(sub, event, depth, caller) do
    payload = %{
      "event_id" => event.id,
      "event_type" => event.event_type,
      "source" => event.source,
      "occurred_at" => to_string(event.occurred_at),
      "payload" => Map.put(event.payload || %{}, "causation_depth", depth + 1)
    }

    # HMAC İmzalama (secret varsa)
    headers = [{"content-type", "application/json"}]
    headers = if sub.secret do
      signature = compute_signature(sub.secret, Jason.encode!(payload))
      [{"x-lrp-signature", signature} | headers]
    else
      headers
    end

    Logger.info("[Dispatcher] Event delivery started. Event: #{event.event_type} -> Webhook: #{sub.webhook_url}")

    if String.starts_with?(sub.webhook_url, "http://mock-webhook") do
      send_mock_notification(sub.webhook_url, payload, caller)
    else
      case Req.post(sub.webhook_url, json: payload, headers: headers, retry: :safe) do
        {:ok, %{status: status}} when status in 200..299 ->
          Logger.info("[Dispatcher] Event delivery successful to #{sub.webhook_url}")
          
        {:ok, response} ->
          log_failure(event.tenant_id, sub, "HTTP Status: #{response.status}")
          
        {:error, reason} ->
          log_failure(event.tenant_id, sub, inspect(reason))
      end
    end
  end

  defp compute_signature(secret, body) do
    :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)
  end

  # Testler için mock bildirim kanalı
  defp send_mock_notification(url, payload, caller) do
    send(caller, {:mock_webhook_delivery, url, payload})
    Logger.info("[Dispatcher Mock] Delivered to #{url}")
  end

  defp log_failure(tenant_id, sub, reason) do
    Logger.error("[Dispatcher] Webhook delivery failed to #{sub.webhook_url}. Reason: #{reason}")

    # Başarısız teslimatları EVENT olarak kaydet (idempotent)
    LRP.log_event(%{
      tenant_id: tenant_id,
      event_type: "webhook_delivery_failed",
      source: "lrp_dispatcher",
      tier: "DURABLE",
      idempotency_key: "delivery_failed:#{sub.id}:#{DateTime.utc_now() |> DateTime.to_unix()}",
      payload: %{
        "subscription_id" => sub.id,
        "webhook_url" => sub.webhook_url,
        "reason" => reason
      }
    })
  end
end
