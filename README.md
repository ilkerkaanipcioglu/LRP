# LRP — Adaptif Kurumsal Çekirdek Sistemi
## Mimari Vizyon ve Object Graph Çekirdek İşletim Sistemi Dokümanı

LRP (Lightweight Resource Planning), kurumsal iş uygulamalarının (ERP, CRM, İK, E-Ticaret, Arşiv vb.) ortak ihtiyaçlarını karşılayan; **Notion + Linear + SAP + Temporal + Git** mimari felsefelerinin hibritleşimiyle tasarlanmış, Elixir tabanlı bir **Object Graph (Nesne Grafiği) İşletim Sistemi** çekirdeğidir.

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

### 4.2 Muhasebe İstisnası

Muhasebe, double-entry zorunluluğu ve denetim/uyumluluk gereksinimleri nedeniyle jenerik nesne grafiğine zorlanmaz; ayrı, katı kurallı bir modül olarak kalır:

```
ACCOUNT(id, tenant_id, code, name, account_type)
JOURNAL(id, tenant_id, doc_date, posting_date, reference)
JOURNAL_LINE(id, journal_id, account_id, party_id[nullable], debit, credit, currency)
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
- **`HOT` (Ajan-Ajan / AgentMesh):** Saniyeler–dakikalar arası yaşar, doğrudan RAM'de (Phoenix.PubSub / NATS memory) tutulur, diske yazılmaz.
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
  - *Rustler NIF*: Elixir ile Rust arasında yüksek hızlı veri köprüsü.
  - *Polars & Petgraph*: Büyük loglarda süreç çıkarımı (Process Mining) ve grafik analizi.
