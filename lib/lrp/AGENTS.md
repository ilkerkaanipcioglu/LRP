# DOX framework — lib/lrp/

- Parent: [LRP root AGENTS.md](../../AGENTS.md)
- Scope: `lib/lrp.ex` ve `lib/lrp/` altındaki tüm Elixir kaynak modülleri

## Local Contract

Bu dizin LRP'nin **çekirdek motorudur**: tüm Ecto şemaları, public API yüzeyi ve adapter modülleri burada yaşar.

**Kritik hatırlatma**: LRP bir protokoldür, Elixir onun referans implementasyonudur. Bu dizindeki kodlar protokol kontratını uygular — protokolü tanımlamaz. Protokol tanımı [`LRP-Mimari-v2-Protokol.md`](../../LRP-Mimari-v2-Protokol.md)'dedir.

---

## Modül İndeksi

| Dosya | Modül | Sorumluluk |
|---|---|---|
| `../../lib/lrp.ex` | `LRP` | Public API — aşağı akış kodunun çağırması gereken tek yüzey |
| `schemas.ex` | `LRP.{Tenant,Actor,Object,Item,Relationship,Event,Policy,ProcessTask,Version,AgentContext,AgentCapability}` | 11 Ecto şema tanımı ve changeset'leri |
| `application.ex` | `LRP.Application` | OTP Application supervisor |
| `repo.ex` | `LRP.Repo` | Ecto.Repo (SQLite3 dev, PostgreSQL prod) |
| `inbox.ex` | `LRP.Inbox` | Broadway tabanlı async event inbox pipeline |
| `source_connector.ex` | `LRP.SourceConnector` | GitHub repo analizi → LRP Object Graph import (ADR-0007 kontratına uyarlanacak) |
| `creator.ex` | `LRP.Creator` | Üretici profil yönetimi, platform bağlantıları ve Güven Skoru hesaplama |
| `funding.ex` | `LRP.Funding` | Proje token fonlaması, yatırımlar ve çift taraflı hasılat payı dağıtımı |

---

## Düzenleme Kuralları

1. **Şema değişiklikleri** (`schemas.ex`), `priv/repo/migrations/` içinde karşılık bir migration gerektirir. Alan tipi değişikliklerini `docs/adr/` altında bir ADR girişi olmadan yapma.

2. **API değişiklikleri** (`lrp.ex`), aynı minor sürüm içinde geriye dönük uyumluluğu korur. Yeni fonksiyonlar ekle; mevcut olanları deprecation yorumu olmadan yeniden adlandırma veya kaldırma.

3. **Doğrudan Repo çağrısı yasaktır** — testler hariç `lrp.ex` dışından `LRP.Repo`'ya erişilmez. Tüm iş mantığı `LRP` public API modülü üzerinden geçer.

4. **`AgentContext` kaydı zorunludur** — `actor_confidence` nil olmayan (yani ajan adına gerçekleştirilen) her yazma işlemi için `LRP.log_agent_context/1` çağrısı `{:ok, _}` dönmeden önce yapılır.

5. **Typespec zorunludur** — `lrp.ex`'teki her public fonksiyon `@spec` anotas yonuna sahip olmalıdır.

6. **HOT event kaybı belgelenmelidir** — `tier: "HOT"` (RAM-only) kullanan her kod, potansiyel veri kaybını yorumda belirtmeli: `# HOT: crash durumunda kaybolabilir — "everything is traceable" bu kapsam dışında`.

---

## Connector Kontratı (ADR-0007)

`LRP.SourceConnector` ve gelecekteki tüm connector modülleri şu `@callback`'leri uygulamalıdır:

```elixir
@callback transform(raw_event :: map()) :: {:ok, LRP.Event.t()} | {:error, term()}
@callback health_check(config :: map()) :: :ok | {:error, term()}
```

`transform/1`: gelen her olayı standart LRP `EVENT` formatına dönüştürür — bu, connectorın tek zorunlu sözleşmesidir.

**`LRP.SourceConnector` için todo**: Mevcut `connect/2` fonksiyonu GitHub verisini OBJECT/EVENT formatına zaten çeviriyor. `@behaviour LRPConnector` eklenerek `transform/1` davranışını uygulaması bekleniyor.

---

## Planlanan Modüller

Aşağıdaki modüller ADR'a bağlı olarak gerçek ihtiyaç doğduğunda eklenir:

| Modül | ADR | Tetikleyici |
|---|---|---|
| `LRP.Capability`, `LRP.Provider`, `LRP.ProviderBinding` | ADR-0004 | İlk gerçek provider swap |
| `LRP.MigrationTracker` | ADR-0005 | İkinci provider'a geçiş günü |
| `LRP.ObservationMode`, `LRP.MaturityScore` | ADR-0006 | İlk müşteri onboarding |
| `LRP.EventSubscription` | ADR-0007 | İlk outbound event ihtiyacı |
| `LRP.Connector` (behaviour) | ADR-0007 | `SourceConnector` refactor'ıyla birlikte |

---

## Yeni Modül Eklerken

1. Bu Modül İndeksi tablosuna ekle.
2. Yeni Ecto şema içeriyorsa, kök AGENTS.md'deki Core Data Model tablosuna da ekle.
3. Yeni public fonksiyonları `lrp.ex`'e ekle.
4. `priv/AGENTS.md`'deki Migration İndeksini güncelle.

- 🔴 **Software Engineering Principles**: Geliştirmeye başlamadan önce mutlaka [ENTERPRISE-ENGINEERING-PRINCIPLES.md](file:///B:/DEV/ENTERPRISE-ENGINEERING-PRINCIPLES.md) dosyasını okuyun, projenin tier seviyesini belirleyin ve kurallara uyun. Eğer bu kurallar dışında bir uygulama yapılacaksa bu durum `AGENTS.md` dosyasında belirtilmelidir; gerekirse `ENTERPRISE-ENGINEERING-PRINCIPLES.md` dosyası proje klasörüne kopyalanıp özelleştirilmiş bir versiyonu oluşturulabilir. Değişiklik küçükse sadece `AGENTS.md` dosyasında belirtilmesi yeterlidir.
