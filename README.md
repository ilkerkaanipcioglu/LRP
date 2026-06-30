# LRP — Adaptif Kurumsal Çekirdek Sistemi
## Mimari Vizyon ve Object Graph Çekirdek İşletim Sistemi Dokümanı

LRP (Lightweight Resource Planning), kurumsal iş uygulamalarının (ERP, CRM, İK, E-Ticaret, Arşiv vb.) ortak ihtiyaçlarını karşılayan; modüler ve olay tabanlı nesne grafiği mimarisiyle tasarlanmış, Elixir tabanlı bir **Object Graph (Nesne Grafiği) İşletim Sistemi** çekirdeğidir.

---

## 1. Mimari Felsefe: "Everything is an Object"

LRP, geleneksel ERP'lerin katı modül/tablo sınırlarını reddeder. AI ajanlarının ve kurumsal süreçlerin esnekçe genişletebileceği tamamen soyut bir nesne grafiği omurgası sunar:

- **Everything is an Object (`OBJECT`):** Müşteri, Tedarikçi, Satış Siparişi, Fatura, İzin Talebi, AI Modeli, Klasör veya Dosya; hepsi `OBJECT` tablosunun birer özelleşmiş (type bazlı) türevidir.
- **Everything emits Events (`EVENT`):** Sistemdeki her nesne oluşturma, güncelleme veya mesajlaşma eylemi bir olay fırlatır.
- **Everything has Relations (`RELATIONSHIP`):** Nesneler ve aktörler arası tüm bağlar jenerik ilişkilerle kurulur.
- **Everything has Attributes (JSONB + `ATTRIBUTE`):** Sık sorgulanan alanlar JSONB `metadata` sütununda tutulurken (hybrid schema), çok seyrek ve dinamik alanlar EAV (`ATTRIBUTE`) tablosunda saklanır.
- **Everything has Versions (`VERSION`):** Git benzeri versiyon kontrolü (`parent_version_id`, `commit_message`) sayesinde AI ajanlarının yaptığı her değişiklik izlenebilir, denetlenebilir ve geri alınabilir.

---

## 2. Mimari Vizyon ve Entegrasyon Matrisi

LRP, Harezm Ekosistemi bünyesindeki kurumsal mantık omurgasını oluştururken, `agentandbot` ve `LesTupid` projeleriyle sıkı bir entegrasyon halinde çalışır:

```
                  ┌──────────────────────────────────────────┐
                  │          LesTupid / Les_Commerce         │
                  │   (UI, Mağaza & Pazaryeri Entegrasyon)   │
                  └────────────────────┬─────────────────────┘
                                       │ (LRP E-commerce'i core alır)
                                       ▼
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                                LRP CORE                                  │
  │   ┌──────────────────────────────────────────────────────────────────┐   │
  │   │                       Core Process Engine                        │   │
  │   │     (Entity DSL, Process Miner Agent, Workflow State Machine)    │   │
  │   └────────────────────────────────┬─────────────────────────────────┘   │
  │                                    │ (Dinler ve Süreç Çıkarır)           │
  │                                    ▼                                     │
  │   ┌──────────────────────────────────────────────────────────────────┐   │
  │   │                 agentandbot / governance_core                    │   │
  │   │     (Rooms, MessagePipeline, ApprovalRequest, AgentEvents, Oban) │   │
  │   └──────────────────────────────────────────────────────────────────┘   │
  └──────────────────────────────────────────────────────────────────────────┘
```

- **LRP CORE (Nesne Grafiği & İş Mantığı):** Dynamic Entity DSL, süreç çıkarım motoru ve otonom durum makinelerini barındırır.
- **LesTupid / Les_Commerce (Arayüz & Entegrasyon):** E-ticaret storefront'larını içerir. Bu uygulamalar **LRP E-commerce yapısını çekirdek (core) olarak kullanır** ve üzerine inşa edilir.
- **agentandbot (İletişim & Orkestrasyon Omurgası):** KADRO persona profillerini, Telegram orkestrasyon proxy'sini, Webhook dinleyicilerini ve insan müdahale katmanını (Pause/Resume/Approve) sunar. LRP, tüm iletişim ve onay akışları için bu sistemi doğrudan kullanır.

---

## 3. Sistem Kurulumu ve Başlangıç Stratejisi (Bootstrapping)

LRP ile yeni bir sisteme başlarken, veri modeli kurmak veya karmaşık süreçler çizmek yerine **Olay Dinleme ve Bağlantı (Connectors) Altyapısı** ile başlanır. Amaç, ilk günden itibaren kurumsal hafızayı ve olay akışını biriktirmektir:

```
  [Gmail / E-posta] ──┐
  [Slack / Discord]  ──┼──▶ [LRP Connectors & Webhooks] ──▶ [EVENT Stream (HOT/WARM/COLD)]
  [ERP / CRM Webh.] ──┘                 │
                                        ▼
                            [LRP Inbox Gateway (CC)]
                                        │
                                        ▼
                            [AI Copilot & Miner Agents]
                            (Yorumlama & Süreç Geliştirme)
```

### 3.1 Adım 1: Bağlantı Noktalarının (Connectors) Entegrasyonu
Sistem kurulur kurulmaz ilk olarak kullanılan iletişim ve ERP araçları LRP'ye bağlanır:
- **Mesajlaşma Webhook'ları:** Slack, Discord, MS Teams webhook ve API'leri dinlenerek kurumsal konuşmalar `EVENT` olarak loglanır.
- **ERP & CRM Olayları:** SAP, Salesforce vb. mevcut sistemlerde oluşan olaylar (örn. fatura kesildi, yeni lead oluştu) LRP olay akışına yönlendirilir.

### 3.2 Adım 2: LRP Inbox Gateway (CC E-posta Entegrasyonu)
Şirketin elinde entegrasyon yapılabilecek hiçbir şey yoksa, LRP için özel bir e-posta adresi açılır (örn: `lrp-inbox@harezm.com`):
- **CC / BCC Yöntemi:** Çalışanlar süreçle ilgili her türlü yazışmada (fatura onayı, teklif gönderimi, sipariş detayları) LRP e-posta adresini **CC** veya **BCC**'ye eklerler.
- **Otomatik Ayrıştırma:** LRP Inbox Gateway (IMAP/SMTP dinleyicisi), bu e-posta kutusuna düşen tüm yazışmaları okur; e-postayı `EVENT` (`source: "email"`) olarak kaydederken, ekteki belgeleri `OBJECT` (`type: "Document"`) ve `ITEM` olarak ayrıştırıp klasörler.

### 3.3 Adım 3: AI Ajanlarının Bağlanması (Copilot & Miner)
Olay akışı akmaya başladığı andan itibaren AI Ajanları sisteme entegre edilir:
- **Yorumlama ve Çıkarım (Process Mining):** Ajanlar olay akışını izleyerek kurumsal süreç kalıplarını çıkarırlar. (Örn: "Müşteri İlker mail attı -> Fatura dökümanı oluşturuldu -> Finans Ajanı onayladı").
- **Kopilot Katmanı:** Ajanlar kullanıcılara "Bu maile göre şu sepeti onaylamak istiyor musunuz?" gibi proaktif önerilerde bulunur ve onay mekanizmalarını (Human-in-the-loop) tetiklerler.

---

## 4. Çekirdek Veri Modeli (9 Core Tablo)

LRP, iş alanına özgü hiçbir kavram bilmez ("müşteri", "fatura" gibi kelimeler şemada geçmez). Tüm kurumsal süreçler bu 9 çekirdek tablo üzerinde koşturulur:

| # | Tablo | Amaç |
|---|---|---|
| 1 | `TENANT` | Çoklu şirket/kiracı izolasyonu — her şey buna bağlıdır |
| 2 | `ACTOR` | İşi yapan yetkili kimlik (User, Employee, AI Agent, Webhook, API, Robot) |
| 3 | `OBJECT` | Party (Taraf), Resource (Kaynak), Document (Belge), Folder (Klasör) — her nesne |
| 4 | `ITEM` | Nesne satırları/maddeleri (Invoice line, checklist item, agenda line vb.) |
| 5 | `RELATIONSHIP` | Nesneler ve aktörler arası jenerik ilişkiler (Contains, AssignedTo, FriendOf vb.) |
| 6 | `EVENT` | Mail geldi, Slack mesajı, API çağrısı, onay verildi — çok kanallı olay akışı |
| 7 | `POLICY` | Erişim kontrol kuralları, roller ve yetki şablonları |
| 8 | `PROCESS_TASK` | Süreç tanımları, çalıştırılan durum makinesi ve görev adımları |
| 9 | `VERSION` | Git benzeri nesne geçmişi ve revizyon denetimi |

### 4.1 Tablo Şemaları ve Alanları

```
TENANT(id, name, status)

ACTOR(id, tenant_id, type[User|Agent|Webhook|API|Robot], name, status)

OBJECT(id, tenant_id, type[Party|Resource|Document|Folder|Case], name, status, metadata[JSONB])

ITEM(id, object_id, parent_item_id, name, quantity, unit_value, currency, metadata[JSONB], status)

RELATIONSHIP(id, from_entity, from_id, to_entity, to_id, relationship_type, valid_from, valid_to)

EVENT(id, tenant_id, event_type, source[email|slack|chat|agent_mesh], occurred_at, payload[JSONB], tier[HOT|WARM|COLD])

POLICY(id, tenant_id, actor_id, resource_type, action[read|write|commit|execute], effect[allow|deny])

PROCESS_TASK(id, tenant_id, process_name, object_id, state, assigned_actor_id, status)

VERSION(id, object_id, parent_version_id, commit_message, committed_by_actor_id, committed_at, object_snapshot[JSONB])
```

### 4.2 Defter Katmanı (Ledger - Muhasebe & Uyum)

Muhasebe, stok envanter bakiyeleri ve banka hesap hareketleri gibi yasal ve değişmez (immutable) çift girişli kayıtlar jenerik nesne grafiğine zorlanmaz. LRP, yasal denetime hazır, VUK, IFRS ve SPK konsolidasyon kurallarına tam uyumlu ayrı bir **Ledger (Defter) Katmanı** barındırır:

#### 1. LEDGER (Defter Tanımı)
Her tenant yasal (Leading - örn: VUK) ve alternatif (non-leading - örn: IFRS) defterlerini burada tutar.
```
LEDGER(id, tenant_id, scheme[VUK|IFRS|SPK_CONSOLIDATED], currency, is_leading, status)
```

#### 2. ACCOUNT (Hesap Planı)
```
ACCOUNT(id, tenant_id, ledger_id, code, name, account_type)
```

#### 3. ACCOUNT_MAPPING (Hesap Planı Çeviri Matrisi)
VUK hesap planı ile IFRS hesap planı arasındaki ilişkiyi kurar.
```
ACCOUNT_MAPPING(id, vuk_account_id, ifrs_account_id, mapping_type)
```

#### 4. JOURNAL (Yevmiye Fişi)
Ekonomik olayların defterlere postalandığı fiş kaydı. `source_event_id` (`EVENT.id`) ile tam izlenebilirlik (audit trail) kurulur. Tek bir olay, VUK ve IFRS defterlerine ayrı ayrı postalanarak iki farklı `JOURNAL` satırı oluşturur.
```
JOURNAL(id, tenant_id, ledger_id, doc_date, posting_date, reference, source_event_id)
```

#### 5. JOURNAL_LINE (Yevmiye Satırı)
Bakiye satırları. Ters kayıt (storno stili) ve vergilendirme detaylarını barındırır. `party_id` alanı, jenerik nesne grafiğindeki `OBJECT.id` alanına soft-referans (UUID) olarak bağlanır.
```
JOURNAL_LINE(id, journal_id, account_id, party_id[soft_ref_uuid], debit, credit, currency, is_reversed, reversed_by_journal_id, vat_code, withholding_code)
```

#### 6. FISCAL_PERIOD (Dönem Kilitleri)
Kapanmış veya kilitlenmiş mali dönemlerde (`posting_date`) geriye dönük kayıt değiştirilmesini DB constraint seviyesinde engeller.
```
FISCAL_PERIOD(id, tenant_id, ledger_id, period_start, period_end, status[open|closed|locked])
```

#### 7. POSTING_RULE (Otomatik Muhasebeleşme Kural Motoru)
Gelen olayların (`EVENT.event_type`) defterlere hangi hesap kodları ve kurallarla postalanacağını tanımlar (SAP Account Determination benzeri).
```
POSTING_RULE(id, tenant_id, event_type, ledger_id, debit_account_id, credit_account_id, amount_formula, condition)
```

#### 8. LEDGER_SEAL (GİB e-Defter Beratı)
Aylık kapanışlarda üretilen GİB e-defter XML imzalarını ve berat hash'lerini değişmez olarak saklar.
```
LEDGER_SEAL(id, ledger_id, period, gib_beratı_hash, signed_at, xml_storage_key)
```

---

## 5. Modül Katmanı — Çekirdeğin Üzerindeki Yorumlama

Klasik ERP/CRM modülleri LRP'de ayrı tablolar değildir; çekirdek tabloların belirli `type`/`relationship_type` değerleriyle filtrelenmiş halleridir:

| Klasik Modül Kavramı | Çekirdekteki Karşılığı |
|---|---|
| Müşteri / Tedarikçi / Personel | `OBJECT` (`type = Party`) + `RELATIONSHIP` (`relationship_type = CUSTOMER / VENDOR / EMPLOYEE`) |
| Satış / Satınalma Siparişi | `OBJECT` (`type = Document`) + `ITEM` |
| Satış Siparişi / Fatura | `OBJECT` (`type = Document`) |
| İzin Talebi | `OBJECT` (`type = Document`) |
| Stok Hareketi | `OBJECT` (`type = Document`) + `ITEM` (giriş/çıkış/transfer/sayım) |
| Malzeme / Makine / Lisans / Dosya | `OBJECT` (`type = Resource`) + `VERSION` |
| CRM Lead / Fırsat | `OBJECT` (`type = Document`) |
| AI Konuşması / Mesaj | `EVENT` (`source = agent_mesh / slack / email`) + `parent_id` (Thread) |
| Dijital Kutu (Folder/Case) | `OBJECT` (`type = Folder`) + `RELATIONSHIP` (`relationship_type = contains`) |
| Fatura ↔ Sipariş İlişkisi | `RELATIONSHIP` (`relationship_type = invoice_of`) |
| Nesnelerin dinamik alanları | `metadata` (JSONB) veya `ATTRIBUTE` |

---

## 6. Hız ve Büyüklük Katmanlandırması (Speed & Size Tiering)

### 6.1 EVENT Hız Katmanları
- **`HOT` (Ajan-Ajan / AgentMesh):** RAM'de (Phoenix.PubSub / NATS memory) akar. Dayanıklılık ve node çökme riskine karşı asenkron olarak geçici bir **Write-Ahead Log (WAL)** dosyasına veya ring-buffer'a yazılır, böylece crash durumunda son state kurtarılabilir.
- **`WARM` (Operasyonel):** "Mail geldi", "Onay istendi" gibi iş olayları. Günler-aylar boyu sorgulanabilir.
- **`COLD` (Kalıcı/Denetim):** Yasal arşiv ve süreç analizine (Process Mining) tabi olan olaylar. PostgreSQL veya append-only sıkıştırılmış S3 arşivinde tutulur.

### 6.2 DOCUMENT Büyüklük Katmanları
- **`INLINE`:** Form verisi, küçük JSON metadata'ları. Doğrudan `OBJECT.metadata` (JSONB) sütununda saklanır.
- **`BLOB` / `LARGE` (PDF, Ekler vb.):** Gerçek dosya içerikleri ilişkisel veritabanına girmez. Obje depolamada (S3/MinIO) tutulur, `OBJECT` üzerinde sadece `storage_key` and `content_hash` metadata'sı taşınır.

---

## 7. Önerilen Teknoloji Yığını

- **Elixir / BEAM (Orkestrasyon & Mesajlaşma Omurgası)**:
  - *Phoenix & LiveView*: Gerçek zamanlı IT onay ekranları ve dashboard arayüzü.
  - *Phoenix PubSub & Channels*: Çift hızlı PubSub topolojisi (Ajan hızı `agent:room` vs. İnsan hızı `human:room`).
  - *Broadway & GenStage*: Yüksek hacimli olay akışını süzmek ve back-pressure yönetmek için.
  - *Oban*: Tekrar denemeli entegrasyonlar ve `paused` durumunda bekleyen insan onay işleri.
  - *Ecto, SQLite3 / PostgreSQL*: Dinamik veri modelleme (JSONB) ve audit trail.
- **Rust (Performans-Kritik Analitik)**:
  - *Rustler NIF*: Elixir ile Rust arasında yüksek hızlı veri köprüsü (Optimizasyon gerekmesi durumunda Phase 2 sonrasında devreye alınacaktır).

---

## 8. Mimari Kararlar ve Sorun Çözümleri (ADR)

### 8.1 EAV Sorgu Bedeli ve CQRS
"Everything is an Object" modelinin (EAV + JSONB) getirdiği karmaşık JOIN sorgularını ve performans düşüşlerini aşmak için **CQRS (Command Query Responsibility Segregation)** uygulanır:
- **Write Path (Yazma):** Nesne grafiği (9 jenerik tablo) üzerinde esnekçe çalışır.
- **Read Path (Okuma/Raporlama):** Arka planda asenkron olarak çalışan event consumer'lar, raporlama ve finansal mutabakat için düzleştirilmiş **Materialized Read Views (Düz Tablolar)** üretir (örn: `InvoiceView`, `CustomerView`). Sorgu ve raporlar doğrudan bu optimize edilmiş düz tablolar üzerinden çekilir.

### 8.2 JSON Patch (RFC 6902) ile Versiyonlama
`VERSION` tablosundaki storage patlamasını önlemek için full snapshot yerine **JSON Patch (RFC 6902)** tabanlı delta/diff yapısına geçilmiştir:
- İlk commit (`v1`) full snapshot (`object_snapshot`) barındırır.
- Sonraki commit'ler (`v2`, `v3` vb.) yalnızca bir önceki versiyonla arasındaki farkı (JSON Patch array) saklar, böylece depolama maliyeti %90 azaltılır.

### 8.3 Multi-Tenant İzolasyonu (Row-Level Security)
Çoklu şirket/kiracı verilerinin güvenliği uygulama kodundaki `where` filtrelerine bırakılamaz. PostgreSQL düzeyinde **Row-Level Security (RLS)** kullanımı zorunludur:
- Her veri talebi öncesinde veritabanı oturumunda `app.current_tenant_id` set edilir.
- RLS policy'leri, bu ID ile eşleşmeyen hiçbir verinin okunmasına veya yazılmasına veritabanı engine seviyesinde izin vermez.

### 8.4 Graph-based Yetkilendirme (ReBAC)
Basit statik roller yerine, nesneler arası ilişkileri baz alan **Relation-based Access Control (ReBAC)** mimarisi uygulanır:
- "Actor X, Document Y'yi okuyabilir" yetkisi, `RELATIONSHIP` tablosundaki graf bağları (örn: `member_of` -> `department_z`) üzerinden dinamik olarak türetilir.

### 8.5 CC E-posta Spoofing ve DKIM/SPF Doğrulaması
 CC/BCC yöntemiyle sisteme giren e-postaların güvenliği için **DKIM/SPF ve Actor Eşleme** kuralları uygulanır:
- LRP Inbox Gateway, gelen maillerin SPF ve DKIM imzalarını doğrulamadan içeri almaz.
- E-postayı gönderen adres, sistemdeki onaylanmış bir `ACTOR` veya `Party` ile eşleşmiyorsa işlem reddedilir veya karantinaya alınır.
