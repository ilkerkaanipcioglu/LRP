# ADR-0007: Standart Connector/Adapter Kontratı + EVENT_SUBSCRIPTION Outbound

- **Tarih**: 2026-06-30
- **Durum**: Uygulandı
- **Kaynak**: [LRP-Mimari-v2-Protokol.md § 8](../LRP-Mimari-v2-Protokol.md)

---

## Bağlam

Mevcut `LRP.SourceConnector`, GitHub repolarını analiz edip LRP Object Graph'ına aktarıyor. Ancak:

1. Standart bir connector kontratı yok — `SourceConnector` bağımsız, diğer connectorlar için şablon oluşturmuyor.
2. Sistem yalnızca dinliyor (inbound); dışarıya event yayını yapamıyor (outbound yok).
3. Dış sistemler `OBJECT.type` veya `RELATIONSHIP.relationship_type` değerlerine bağımlı hâle gelince, bu değerler değiştiğinde entegrasyonlar sessizce kırılıyor.

---

## Karar

### 1. Standart Connector Kontratı

Her connector şu kontratı uygular:

```sql
CONNECTOR (
  id          UUID PRIMARY KEY,
  tenant_id   UUID NOT NULL,
  type        TEXT NOT NULL,    -- github | slack | email | efatura | logo | ...
  config      JSONB NOT NULL,   -- connector'a özgü konfigürasyon
  auth_method TEXT NOT NULL,    -- oauth2 | api_key | basic | webhook_secret
  status      TEXT DEFAULT 'active'  -- active | paused | error | deprecated
)
```

Her connector Elixir modülü şu davranışı uygular:

```elixir
@callback transform(raw_event :: map()) :: {:ok, LRP.Event.t()} | {:error, term()}
@callback health_check(config :: map()) :: :ok | {:error, term()}
```

`transform/1` tek zorunlu fonksiyondur: her gelen olayı standart LRP `EVENT` formatına dönüştürür. Bu, MCP'nin araç tanımlarıyla da uyumludur.

**Mevcut `LRP.SourceConnector`** bu kontrata uyacak şekilde refactor edilmelidir: GitHub'dan gelen repo verilerini zaten OBJECT/EVENT formatına çeviriyor; `transform/1` davranışını ekleme yeterli olacaktır.

### 2. Outbound Event Yayını

Sistem şu an yalnızca dinliyor. Dışarıya yayın için:

```sql
EVENT_SUBSCRIPTION (
  id                  UUID PRIMARY KEY,
  tenant_id           UUID NOT NULL,
  actor_id            UUID REFERENCES ACTOR,     -- abone olan actor
  event_type_pattern  TEXT NOT NULL,            -- "invoice.*" | "agent.decision" | "*"
  webhook_url         TEXT NOT NULL,
  secret              TEXT,                      -- HMAC imzalama için
  max_causation_depth INTEGER DEFAULT 3,         -- bu abonelik için izin verilen max döngü derinliği
  status              TEXT DEFAULT 'active',
  created_at          TIMESTAMPTZ NOT NULL
)
```

Outbound akışı:
1. EVENT yazılır (mevcut flow değişmez). Zincirsel olaylarda `causation_depth` 1 artırılır.
2. `EVENT_SUBSCRIPTION` kayıtları `event_type_pattern` ve `event.causation_depth <= subscription.max_causation_depth` kuralına göre filtrelenir (böylece döngüler engellenir).
2. `EVENT_SUBSCRIPTION` kayıtları `event_type_pattern`'a göre eşleştirilir.
3. Eşleşen webhook URL'lerine HMAC-imzalı POST gönderilir.
4. Başarısız delivery'ler `EVENT(event_type="webhook_delivery_failed")` olarak kaydedilir (idempotency_key ile).

### 3. Şema Versiyonlama Sözleşmesi

Dış sistemler `OBJECT.type`, `RELATIONSHIP.relationship_type`, `EVENT.event_type` değerlerine bağımlı hâle gelir. Kırılmayı önlemek için:

- **API versiyonlama**: Tüm dış yüzey `/api/v1/` prefix'iyle sunulur.
- **Type alanları silinmez, yalnızca deprecated işaretlenir**: `OBJECT.type = "SourceSystem"` → kullanım dışı kalırsa yeni tip eklenir, eski tip bırakılır.
- **Breaking change'ler yeni bir major sürüm gerektirir** (`/api/v2/`).

### E-Fatura (GİB UBL-TR)

Çekirdek değişmez. `integrations/efatura` modülü:
- `OBJECT(type="Document")` → faturayı karşılar
- `EVENT(source="e-fatura")` → GİB event'ini karşılar
- `OBJECT.metadata` içine `gib_uuid`, `ettn`, `signature_status` eklenir

### Web3 / Tamper-Proof Audit

`VERSION.object_snapshot` hash'i periyodik olarak bir chain'e anchor ederek "bu kayıt şu tarihte böyleydi" kanıtı üretilebilir. Akıllı kontrat/token/wallet entegrasyonu kapsam dışıdır; çekirdeğin yalnızca "hash/anchor edilebilir" olması yeterlidir.

---

## Sonuçlar

**Olumlu:**
- `transform/1` kontratı, her yeni connector'ı öngörülebilir kılar.
- `EVENT_SUBSCRIPTION` ile LRP aktif bir entegrasyon merkezi olur (sadece pasif dinleyici değil).
- Şema versiyonlama sözleşmesi, entegrasyonların sessizce kırılmasını önler.

**Riskler / Dikkat:**
- `SourceConnector`'ın `@callback` davranışına uyarlanması küçük bir refactoring gerektirir — mevcut testler bu sırada korunmalıdır.
- `EVENT_SUBSCRIPTION` webhook delivery için güvenilir bir kuyruk mekanizması gerektirir (Oban bu iş için uygundur).
- `secret` alanı şifrelenmiş olarak saklanmalı; plaintext olarak veritabanına yazılmamalıdır.

---

## İlgili Kararlar

- ADR-0004 (Capability/Provider) — Connector bir tür `PROVIDER` olarak modellenebilir.
- ADR-0006 (Observation Mode) — Gölge mod için dış sistem bağlantısı bu kontrat üzerinden çalışır.
