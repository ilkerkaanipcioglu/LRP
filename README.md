# LRP — AI-native Enterprise Operating System

```
LRP

ERP is not software.
ERP is a knowledge graph.

Everything is an entity.
Everything is an event.
Everything is traceable.
Everything is explainable.
```

### Why LRP?



???

* **SAP** ──▶ Transaction driven
* **Odoo** ──▶ Module driven
* **LRP** ──▶ **Knowledge driven**

LRP (Lightweight Resource Planning), kurumsal iş süreçlerini ve varlıklarını modüller yerine **AI-Native Nesne Grafiği (Knowledge Graph)** ve **Olay Akışı (Event Sourcing)** olarak yöneten, her iş nesnesinin bir varlık, her değişikliğin bir olay, her iş akışının şeffaf/açıklanabilir olduğu ve kararların insan ile AI ajanları arasında delege edilebildiği yeni nesil bir **Kurumsal İşletim Sistemi (Enterprise OS)** çekirdeğidir.

---

## 1. Mimari Prensipler

### 1.1 "Everything is an Entity / Object" (Nesne Grafiği)

LRP, geleneksel ERP'lerin katı tablo sınırlarını reddeder. Sistemdeki her kavram (Müşteri, Tedarikçi, Fatura, AI Modeli, İzin Talebi, Klasör veya Dosya) jenerik birer `OBJECT`tir (Entity).

* **Business Partner (BP) Birleştirmesi:** Müşteri, Tedarikçi, Personel, Taşıyıcı veya Devlet dairesi ayrı tablolar değildir; hepsi `Party` türünde birer jenerik `OBJECT`tir ve sonradan eklenebilen roller (`PartyRole`) aracılığıyla esneklik kazanırlar.
* **Semantic Layer (Anlamsal Graf):** Varlıklar arasındaki bağlar `RELATIONSHIP` tablosuyla anlamsal bir graf olarak tutulur (örn: `Customer owns Contract contains Product stored in Warehouse`). AI bu grafı doğrudan sorgulayarak kurumsal ilişkileri milisaniyede analiz eder.

### 1.2 Event Sourcing & Projection (Değişmezlik)

LRP veritabanında doğrudan `UPDATE` veya `DELETE` komutları kullanılmaz. Sistem durumunu değiştiren her eylem append-only birer olay (`EVENT`) olarak kaydedilir:

* `EntityCreated`, `EntityChanged`, `StockMoved`, `InvoicePosted`, `PaymentReceived`.
* Anlık stok durumu (Current Stock), cari bakiye (Current Balance) gibi güncel durumlar, bu olay akışının asenkron veya anlık **Projections (Okuma Modelleri)** tarafından işlenmesiyle dinamik olarak üretilir.

### 1.3 AI as Runtime (Yapay Zeka Çalışma Zamanı)

AI, LRP için sonradan eklenen bir "özellik/asistan" değil, sistemin **runtime (çalışma zamanı)** katmanıdır. Bir veri kaydı (`entity.create()`) esnasında AI runtime şu adımları otomatik tetikler:

```
[entity.create()] ──▶ [AI Validation] ──▶ [Duplicate Detection] ──▶ [Risk Scoring] ──▶ [Workflow Suggestion] ──▶ [Save]
```

### 1.4 AI Router & Classifier (Model Yönlendirme)

Çekirdek bünyesinde barınan akıllı yönlendirici, gelen isteklerin (Request) maliyet ve karmaşıklığına göre doğru LLM'e yönlendirilmesini sağlar:

```
[Request] ──▶ [Classifier] ──▶ [Cheap Model | Reasoning Model | Local LLM | External LLM]
```

### 1.5 Explainability (Açıklanabilirlik)

Sistemde AI ajanları tarafından alınan her karar veya yapılan her öneri şeffaftır. Kullanıcı "Neden?" sorduğunda, AI karar izini (fatura geçmişi, tedarikçi skoru, teslimat gecikmeleri, ödeme davranışları) anlamsal graf üzerinden açıklamak zorundadır.

---

## 2. Repository Dizin Yapısı (Domain Driven Design)

LRP, modül-tabanlı (satış, muhasebe) değil, domain-tabanlı bir klasör organizasyonu (DDD) sunar:

```
lrp/
  ├── core/          # LRP Runtime Engine & supervisor ağaçları
  ├── entity/        # Dynamic Entity DSL & Object Graph motoru
  ├── event/         # Event Sourcing, HOT/WARM/COLD stream ve WAL
  ├── workflow/      # Durum makineleri, Temporal & Oban onay akışları
  ├── ledger/        # VUK, IFRS, SPK değişmez defter katmanı (Ledger)
  ├── ai/            # AI Router, classifier ve prompt templates
  ├── agents/        # Process Miner, Compliance Auditor, Copilot vb.
  ├── plugins/       # Capability SDK (Workflows, AI tools, UI injection)
  ├── api/           # ACP (Agent Control Protocol) JSON-RPC & REST
  ├── ui/            # IT Yönetim dashboard'u & onay ekranları
  ├── docs/          # ADR (Architectural Decision Records) dosyaları
  └── examples/      # Örnek entegrasyonlar ve PoC kodları
```

---

## 3. Çekirdek Veri Modeli (9 Core Tablo)

| #   | Tablo          | Amaç                                                                         |
| --- | -------------- | ---------------------------------------------------------------------------- |
| 1   | `TENANT`       | Çoklu kiracı izolasyonu (PostgreSQL RLS ile korunan sınır)                   |
| 2   | `ACTOR`        | İşi yapan yetkili kimlik (User, Employee, AI Agent, Webhook, API, Robot)     |
| 3   | `OBJECT`       | Party, Resource, Document, Folder, Case — her jenerik nesne                  |
| 4   | `ITEM`         | Nesne satırları/maddeleri (Invoice line, checklist item, agenda line vb.)    |
| 5   | `RELATIONSHIP` | Nesneler ve aktörler arası jenerik ilişkiler (ReBAC yetki kontrolleri dahil) |
| 6   | `EVENT`        | Mail, Slack, Webhook ve AgentMesh asenkron olay akışı                        |
| 7   | `POLICY`       | Erişim kontrol kuralları, roller ve yetki şablonları                         |
| 8   | `PROCESS_TASK` | Süreç tanımları, çalıştırılan durum makinesi ve görev adımları               |
| 9   | `VERSION`      | JSON Patch (RFC 6902) tabanlı nesne geçmişi ve revizyon denetimi             |

---

## 4. Defter Katmanı (Ledger - Muhasebe & Uyum)

Çift girişli muhasebe, yasal defterler (VUK), uluslararası raporlama (IFRS) ve SPK konsolidasyon kuralları için tasarlanmış değişmez (immutable) defter şemasıdır. `JOURNAL_LINE.party_id` referansı, jenerik nesne grafiğindeki `OBJECT.id` alanına soft-referans (UUID) olarak bağlanır.

```
LEDGER(id, tenant_id, scheme[VUK|IFRS|SPK_CONSOLIDATED], currency, is_leading, status)
ACCOUNT(id, tenant_id, ledger_id, code, name, account_type)
ACCOUNT_MAPPING(id, vuk_account_id, ifrs_account_id, mapping_type)
JOURNAL(id, tenant_id, ledger_id, doc_date, posting_date, reference, source_event_id)
JOURNAL_LINE(id, journal_id, account_id, party_id[soft_ref_uuid], debit, credit, currency, is_reversed, vat_code, withholding_code)
FISCAL_PERIOD(id, tenant_id, ledger_id, period_start, period_end, status[open|closed|locked])
POSTING_RULE(id, tenant_id, event_type, ledger_id, debit_account_id, credit_account_id, amount_formula, condition)
LEDGER_SEAL(id, ledger_id, period, gib_beratı_hash, signed_at, xml_storage_key)
```

---

## 5. Mimari Kararlar ve Sorun Çözümleri (ADR)

Detaylı teknik gerekçeler ve kararlar için `docs/adr/` dizinindeki ADR dosyalarını inceleyin:

- **[ADR-0001: CQRS Read Views](docs/adr/0001-cqrs-read-views.md):** Sorgu yavaşlığını aşmak için asenkron düzleştirilmiş Read Views tabanının kurulması (Staleness sözleşmesi: max 5 saniye gecikme).
- **[ADR-0002: JSON Patch Versioning](docs/adr/0002-json-patch-versioning.md):** Full snapshot depolama yükünü önlemek için JSON Patch (RFC 6902) diff yapısı ve 50 patch squash (compaction) kuralı.
- **[ADR-0003: ReBAC Authorization](docs/adr/0003-rebac-authorization.md):** İlişki bazlı dinamik yetkilendirme yeteneği.

---

## 6. Yol Haritası (Roadmap)

* **v0.1 — Entity Engine (Mevcut):** 9 Çekirdek Tablo Ecto şemaları ve test edilmiş minimal PoC.
* **v0.2 — Workflow Engine:** Durum makinesi durum geçişleri ve event trigger yapısı.
* **v0.3 — Ledger:** VUK, IFRS hesap planı ve dönem kilitleri entegrasyonu.
* **v0.4 — AI Router:** Classifier ve akıllı model yönlendirme katmanı.
* **v0.5 — Agent Framework:** `governance_core` entegrasyonu ve A2A AgentMesh.
* **v0.6 — Plugin SDK:** Dynamic capabilities ve form metadata runtime.
* **v1.0 — Production Ready:** Canlı ortam ve SPK/GİB uyumlulukları.

---

## 7. PoC Verification Status

- **Verification:** Integration tests successfully verified the complete flow (emails, events, relationships, RLS migration specs, and versioning snapshots). All tests pass with 0 failures.
