# DOX framework — LRP root

- DOX is a highly performant AGENTS.md hierarchy installed here.
- Agent must follow DOX instructions across any edits.

## Core Contract

- AGENTS.md files are binding work contracts for their subtrees.
- Work products, source materials, instructions, records, assets, and durable docs must stay understandable from the nearest applicable AGENTS.md plus every parent AGENTS.md above it.

## Read Before Editing

- 🔴 **Software Engineering Principles**: Geliştirmeye başlamadan önce mutlaka [ENTERPRISE-ENGINEERING-PRINCIPLES.md](file:///B:/DEV/ENTERPRISE-ENGINEERING-PRINCIPLES.md) dosyasını okuyun, projenin tier seviyesini belirleyin ve kurallara uyun. Eğer bu kurallar dışında bir uygulama yapılacaksa bu durum `AGENTS.md` dosyasında belirtilmelidir; gerekirse `ENTERPRISE-ENGINEERING-PRINCIPLES.md` dosyası proje klasörüne kopyalanıp özelleştirilmiş bir versiyonu oluşturulabilir. Değişiklik küçükse sadece `AGENTS.md` dosyasında belirtilmesi yeterlidir.
1. Read this root AGENTS.md.
2. Identify every file or folder you expect to touch.
3. Walk from the repository root to each target path.
4. Read every AGENTS.md found along each route.
5. If a parent AGENTS.md lists a child AGENTS.md whose scope contains the path, read that child and continue from there.
6. Use the nearest AGENTS.md as the local contract and parent docs for repo-wide rules.
7. If docs conflict, the closer doc controls local work details, but no child doc may weaken DOX.

Do not rely on memory. Re-read the applicable DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass before the task is done.

Update the closest owning AGENTS.md when a change affects:
- purpose, scope, ownership, or responsibilities
- durable structure, contracts, workflows, or operating rules
- required inputs, outputs, permissions, constraints, side effects, or artifacts
- user preferences about behavior, communication, process, organization, or quality
- AGENTS.md creation, deletion, move, rename, or index contents

Update parent docs when parent-level structure, ownership, workflow, or child index changes. Update child docs when parent changes alter local rules. Remove stale or contradictory text immediately. Small edits that do not change behavior or contracts do not require DOX updates.

---

## Local Details

- **Role**: LRP (Lightweight Resource Planning) — AI-native Enterprise Operating System core engine.
- **Tier Classification**: **Tier 4 (Büyük / Kurumsal)** olarak tescil edilmiştir. LRP; katmanlı modüler monolith mimarisi, multi-tenant izole şema/veritabanı destekleri, audit loglama, OpenFGA tabanlı ReBAC, CQRS read model, asenkron webhook sub/pub yapısı ve hata tolere edici (circuit breaker) entegrasyonlar gibi Tier 4 kurumsal mühendislik standartlarının tamamını hedefler ve uygular.
- **Language/Runtime**: Elixir 1.15+/BEAM (referans implementasyon). LRP bir protokoldür — Rust, PHP, Python, Go, Java ile de uygulanabilir.
- **Version**: v0.1.0 (Entity Engine; Workflow, Ledger, AI katmanları planlanmış).
- **Architecture Spec**: [`LRP-Mimari-v2-Protokol.md`](LRP-Mimari-v2-Protokol.md) — bu doküman teknik karar kaynağıdır.

---

## En Önemli Mimari Karar: LRP Bir Protokoldür, Runtime Değil

> **LRP, belirli bir programlama diline bağlı bir çalışma zamanı değil; TENANT/OBJECT(ACTOR)/EVENT üçlüsüne dayanan bir veri sözleşmesi ve entegrasyon kontratıdır.**

- Elixir bu kontratta **referans implementasyon**dur, zorunluluk değildir.
- Rust, PHP, Python, Go, Java ile de aynı LRP mantığı uygulanabilir — yeter ki OBJECT/EVENT/CONNECTOR kontratına uysun.
- LRP hiç "çalıştırılmadan", salt bir **metodoloji/şablon** olarak da kullanılabilir (mevcut sistemi dokümante etmek için).

---

## Binding Design Contracts

Her ajan ve geliştirici bu sözleşmeleri zorunlu olarak uygular:

1. **Knowledge Graph OS — Not ERP**: Her şey `OBJECT` veya `EVENT`'tir. Çekirdek şemada domain-spesifik tablo isimleri (customer, invoice, stock) yoktur.

2. **EAV Tablosu Yoktur**: Önceki taslaklarda değerlendirilen ayrı EAV tablosu **bilinçli olarak kaldırılmıştır**. PostgreSQL JSONB + GIN index, EAV'in yaptığı her şeyi tek noktadan yapar. `OBJECT.metadata` (JSONB) tüm dinamik alanların tek adresidir.

3. **No Direct UPDATE or DELETE (Event Sourcing)**: Üretim tablolarında entity veri alanları direkt güncellenmez/silinmez. Değişiklikler append-only `EVENT` kayıtları olarak modellenir. Anlık durumlar **Projection** ile hesaplanır.

4. **Strict CQRS Isolation**: Karmaşık analiz/raporlama sorguları `OBJECT` veya `RELATIONSHIP` yazma tablolarına direkt çalıştırılmaz. Tüm raporlama materyalize okuma modeli (Read View) üzerinden, maksimum 5 saniye gecikmeyle yapılır. (ADR-0001)

5. **İki Katmanlı Hız Modeli (HOT / DURABLE)**: Üç katmanlı (HOT/WARM/COLD) model bilinçli olarak ikiye indirilmiştir. `WARM` ve `COLD` arasındaki fark TTL/retention policy ile tek katmanda çözülür. Daha az kod yolu = daha az hata yüzeyi.

6. **Database Level Security (RLS)**: Tüm Ecto sorguları `tenant_id` bağlamını taşır ve zorunlu kılar. PostgreSQL'de Row-Level Security (RLS) politikaları aktif ve etkin olmalıdır.

7. **JSON Patch (RFC 6902) Versioning**: Nesne versiyonlama JSON Patch dizileri kullanır. Her 50 patch'te bir compaction otomatik tetiklenir. (ADR-0002 — planlanmış)

8. **ReBAC Authorization**: Yetkilendirme kontrolleri `RELATIONSHIP` grafiğini gezerek dinamik olarak çözülür, OpenFGA pattern'larıyla hizalı. (ADR-0003 — planlanmış; bugün statik `Policy` tablosu kullanılıyor)

9. **Agent-Native Explainability**: Her ajan eylemi `AgentContext` kaydı oluşturur: `reasoning_trace`, `confidence_score`, `model_version`, `prompt_hash`. `actor_confidence: nil` = insan; `0.0–1.0` = ajan.

10. **Idempotent Events**: Ajanlar veya entegrasyonlar tarafından yayılan tüm eventler `idempotency_key` taşır. Yinelenen insert'ler veritabanı seviyesinde unique constraint ile reddedilir.

11. **Hot-Swap Provider Pattern**: Her capability (not alma, fatura onayı, muhasebe) bir `CAPABILITY` sözleşmesiyle tanımlanır; gerçek işi yapan `PROVIDER` değiştirilebilir — çekirdek OBJECT/EVENT katmanı değişmeden. (ADR-0004 — planlanmış)

12. **Kapsam Disiplini**: "En iyi çekirdek" hedefi planlama girdisi olarak kullanılmaz — sonsuz kapsam üretir. Her ek, gerçek bir acı noktasından türetilir, varsayımdan değil.

---

## Uygulama Sırası (v2 Protokol)

| Sıra | Adım | Kapsam | Durum |
|---|---|---|---|
| 1 | Çekirdek demo | `TENANT/ACTOR/OBJECT/EVENT` + basit inbox, tek akış uçtan uca | ✅ Done (v0.1) |
| 2 | Agent-native temel | `idempotency_key`, `actor_confidence`, `reasoning_trace` | ✅ Done (v0.1) |
| 3 | Onboarding iskeleti | Sihirbaz (sıfırdan/mevcut) + `MATURITY_SCORE` v0 | 🔲 Planned (ADR-0006) |
| 4 | Şema sadeleştirme | EAV kaldırıldı ✅, hız katmanı ikiye indi ✅ | ✅ Already aligned |
| 5 | İlk gerçek entegrasyon | Tek Connector (Slack/e-posta) + insan onaylı sınıflandırma | 🔲 Planned (ADR-0007) |
| 6 | Capability/Provider/Binding | Gerçek upgrade/downgrade ihtiyacı doğunca | 🔲 Planned (ADR-0004) |
| 7 | MIGRATION_TRACKER | İkinci provider'a fiilen geçilmeye çalışıldığı gün | 🔲 Planned (ADR-0005) |
| 8 | Embedding/semantic katman | Agent retrieval ihtiyacı somutlaşınca | 🔲 Planned |
| 9 | Performans katmanı (Rust/NIF) | Yalnızca "Elixir burada yetersiz" ölçümle kanıtlandıktan sonra | 🔲 Phase 3 |
| 10 | Web3/e-fatura/dış sistemler | Connector kontratı üzerinden, çekirdeğe dokunmadan, talep geldikçe | 🔲 On demand |

---

## Core Data Model

### Çekirdek 6 Tablo (Protokol Çekirdeği)

| # | Modül | Tablo | Amaç |
|---|---|---|---|
| 1 | `LRP.Tenant` | `tenants` | Çok kiracı izolasyonu |
| 2 | `LRP.Actor` | `actors` | Kimlik: User, Agent, Webhook, API, Robot |
| 3 | `LRP.Object` | `objects` | Her şey: Party, Resource, Document, Folder, Case |
| 4 | `LRP.Event` | `events` | Append-only event stream; HOT (RAM) \| DURABLE (DB) |
| 5 | `LRP.Relationship` | `relationships` | Semantik grafik kenarları (ReBAC temeli) |
| 6 | `LRP.Version` | `versions` | Nesne revizyon geçmişi |

### Agent-Native Uzantılar (v0.1'de Uygulanmış)

| # | Modül | Tablo | Amaç |
|---|---|---|---|
| 7 | `LRP.Item` | `items` | Object'e ait satır kalemleri |
| 8 | `LRP.Policy` | `policies` | Statik allow/deny kuralları (ReBAC gelene kadar) |
| 9 | `LRP.ProcessTask` | `process_tasks` | İş akışı durum makinesi adımları |
| 10 | `LRP.AgentContext` | `agent_contexts` | Ajan karar denetim kaydı |
| 11 | `LRP.AgentCapability` | `agent_capabilities` | MCP-uyumlu araç kayıt defteri |

### Planlanan Tablolar (Gerçek İhtiyaç Doğunca Eklenir)

| Tablo | ADR | Tetikleyici |
|---|---|---|
| `CAPABILITY`, `PROVIDER`, `PROVIDER_BINDING` | ADR-0004 | İlk gerçek provider swap ihtiyacı |
| `MIGRATION_TRACKER` | ADR-0005 | İkinci provider'a geçiş günü |
| `OBSERVATION_MODE` | ADR-0006 | İlk müşteri onboarding |
| `EVENT_SUBSCRIPTION` | ADR-0007 | İlk outbound event ihtiyacı |
| `TASK` genişletmesi (`assignment_mode`, `reassignment_reason`, `previous_actor_id`) | ADR-0004 | Agent↔insan görev değişimi izleme |

---

## Directory Index

| Yol | AGENTS.md | Kapsam |
|---|---|---|
| [`lib/lrp/`](lib/lrp/AGENTS.md) | ✅ | Tüm Elixir modülleri — şemalar, API, connector'lar |
| [`docs/`](docs/AGENTS.md) | ✅ | Architecture Decision Records ve dokümantasyon |
| [`test/`](test/AGENTS.md) | ✅ | Entegrasyon ve birim testleri |
| [`config/`](config/AGENTS.md) | ✅ | Runtime ve veritabanı konfigürasyonu |
| [`priv/`](priv/AGENTS.md) | ✅ | Veritabanı migration'ları |

---

## Key Commands

```bash
mix deps.get        # bağımlılıkları yükle
mix ecto.create     # geliştirme veritabanı oluştur
mix ecto.migrate    # migration'ları çalıştır
mix test            # tüm testleri çalıştır
```
