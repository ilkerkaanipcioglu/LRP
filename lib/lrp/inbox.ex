defmodule LRP.Inbox do
  @moduledoc """
  LRP Inbox Gateway — E-posta, Slack ve webhook girdilerini normalize eder.

  Akış:
    ingest_email/2
      → EVENT (email_received, DURABLE, idempotency_key)
      → OBJECT (Document, e-posta metadatası)
      → RELATIONSHIP (event → document: "triggered")

  Bu akış LRP'nin gerçek dünya sorununu nasıl çözdüğünü gösteren
  minimum çalışan kanıttır.
  """

  alias LRP.Repo
  alias LRP.{Object, Event, Relationship}

  @doc """
  Gelen bir e-postayı LRP'ye alır.

  ## Parametreler
    - tenant_id: binary_id
    - email: map — :message_id, :from, :to, :subject, :body, :received_at (optional)

  ## Dönüş
    {:ok, %{event: event, document: document}} veya {:error, reason}
  """
  def ingest_email(tenant_id, email) do
    message_id = Map.fetch!(email, :message_id)
    idempotency_key = "email:#{message_id}"
    received_at = Map.get(email, :received_at, DateTime.utc_now())

    Repo.transaction(fn ->
      # 1. EVENT — e-postayı normalize et, DURABLE tier'a yaz
      {:ok, event} =
        LRP.log_event(%{
          tenant_id: tenant_id,
          event_type: "email_received",
          source: "email",
          tier: "DURABLE",
          occurred_at: received_at,
          idempotency_key: idempotency_key,
          payload: %{
            "message_id" => message_id,
            "from"       => Map.get(email, :from),
            "to"         => Map.get(email, :to),
            "subject"    => Map.get(email, :subject),
            "body_preview" => email |> Map.get(:body, "") |> String.slice(0, 500)
          }
        })

      # 2. OBJECT (Document) — e-postayı iş nesnesine dönüştür
      {:ok, document} =
        LRP.create_object(%{
          tenant_id: tenant_id,
          type: "Document",
          name: Map.get(email, :subject, "(konu yok)"),
          status: "active",
          metadata: %{
            "source"     => "email",
            "from"       => Map.get(email, :from),
            "to"         => Map.get(email, :to),
            "message_id" => message_id,
            "received_at" => DateTime.to_iso8601(received_at)
          }
        })

      # 3. RELATIONSHIP — event bu document'ı tetikledi
      {:ok, _rel} =
        LRP.relate("Event", event.id, "Document", document.id, "triggered")

      %{event: event, document: document}
    end)
  end

  @doc """
  Tekrarlayan (retry) e-postaları güvenle işler.
  Aynı message_id ile gelen e-posta idempotent olarak reddedilir,
  mevcut event ve document döndürülür.
  """
  def ingest_email_idempotent(tenant_id, email) do
    import Ecto.Query
    message_id = Map.fetch!(email, :message_id)
    idempotency_key = "email:#{message_id}"

    # Transaction'dan ÖNCE kontrol et — rollback sorununu önler
    case Repo.one(from(e in Event, where: e.idempotency_key == ^idempotency_key, limit: 1)) do
      nil ->
        ingest_email(tenant_id, email)

      existing_event ->
        relationships = LRP.list_relationships("Event", existing_event.id, "triggered")
        document_id = List.first(relationships).to_id
        document = LRP.get_object(document_id)
        {:ok, %{event: existing_event, document: document, duplicate: true}}
    end
  end

end
