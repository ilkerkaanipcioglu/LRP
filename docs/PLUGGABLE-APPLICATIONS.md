# LRP — Değişebilir Uygulamalar Prensibi (Pluggable Applications Principle)
*Her capability başlangıçta en basit araçla karşılanır, ihtiyaç büyüdükçe LRP native çözüme kademeli geçilir.*

---

## Temel Kural

```
Başlangıç → Büyüme → LRP Native
   .md    →  n8n   →  Oban + BEAM
  email   →  Slack →  PubSub + Channels
  excel   →  Logo  →  LRP Ledger
 manuel   → LangChain → AgentContext + BEAM
```

**LRP hiçbir zaman araca bağımlı olmaz.**  
**Araç her zaman LRP'ye bağlıdır.**  
**Geçiş her zaman kademeli, her zaman geri dönülebilir.**  

---

## ⚠️ LRP'nin Kendi Yapacakları — Değiştirilemez Core

Bunlar hiçbir 3rd party tool'a devredilemez. Audit, güven ve para burada yaşar.

| Capability | Neden Core | Alternatif Yok |
|---|---|---|
| **Agent-to-Agent Mesajlaşma** | Confidence scoring, audit trail ve ACTOR modeli LRP'de işlenir. | n8n agent kararlarını ve güven akışını izleyemez. |
| **Workflow / Flow Engine** | Her adım `PROCESS_TASK`, IT onayı ve pause/resume LRP'de yönetilir. | Crash sonrası kaldığı yerden güvenle devam etme Oban/BEAM ile sağlanır. |
| **Ledger / Muhasebe** | VUK/IFRS, değişmezlik ve `FISCAL_PERIOD` kilidi DB seviyesinde korunmalıdır. | Denetim izi LRP dışına çıkarılamaz. |
| **Versiyonlama / Audit Trail** | Her karar, her değişiklik ve her onay değişmez olarak izlenir. | 3rd party araçlar LRP veri modelini derinlemesine bilemez. |
| **Tenant / Kimlik / Yetki** | Row-Level Security (RLS) veritabanı seviyesindedir, taşınamaz. | Güvenlik ve veri izolasyonu çekirdekte kalmalıdır. |
| **Idempotency** | Hangi tool kullanılırsa kullanılsın mükerrer kaydı LRP korur. | Tool değişse bile idempotency garantisi LRP'dedir. |

---

## 📦 Capability Kataloğu — Başlangıç → LRP Native

### 1. FLOW / WORKFLOW
**Ne işe yarar:** İş adımlarını sırayla yürütür, onay bekler, dallanır.

* **Seviye 1 — .md dosyası**
  * *Artıları:* Sıfır kurulum, herkes okuyabilir.
  * *Eksileri:* Otomatik değil, tamamen manuel takip gerektirir.
  * *Kullanım:* İlk prototip, 1-2 kişilik ekipler.
* **Seviye 2 — n8n / Windmill**
  * *Artıları:* Görsel flow tasarımı, 300+ hazır entegrasyon.
  * *Eksileri:* Crash audit trail yok, Agent confidence (güven skoru) bilmiyor.
  * *Kullanım:* Orta ölçek, 3rd party entegrasyonların yoğun olduğu senaryolar.
* **Seviye 3 — LRP Native (PROCESS_TASK + Oban + BEAM) [HEDEF]**
  * *Artıları:* Her adım `EVENT` olarak izlenir, crash sonrası kaldığı yerden devam eder, IT onayı entegredir, eskalasyonlar confidence oranına göre otomatik yapılır, pause/resume insan müdahalesine açıktır.
  * *Kullanım:* Kritik iş akışları, finansal onaylar, otonom agent görevleri.

> **Geçiş Tetikleyicisi:**
> * Günde 10+ manuel adım → Seviye 1'den 2'ye geçiş.
> * Hata oranı %5+ veya denetim/audit talebi → Seviye 2'den 3'e geçiş.

---

### 2. ZAMANLAMA / CRON
**Ne işe yarar:** Belirli zamanlarda görevleri tetikler.

* **Seviye 1 — Sistem cron / .sh script**
  * *Artıları:* Her Linux'ta hazır, sıfır kurulum.
  * *Eksileri:* Tek sunucu sınırlaması (dağıtık değil), ilkel hata loglaması.
  * *Kullanım:* Tek sunucu, basit cron görevleri.
* **Seviye 2 — n8n Schedule / Windmill Cron**
  * *Artıları:* Görsel zamanlama yönetimi, retry mantığı.
  * *Eksileri:* Ayrı servis yönetimi ve bakım maliyeti.
  * *Kullanım:* Görsel izleme ve yönetim isteniyorsa.
* **Seviye 3 — LRP Native (Oban + BEAM) [HEDEF]**
  * *Artıları:* PostgreSQL/DB üzerinde çalışır (ekstra servis yok), tenant bazlı zamanlama, crash sonrası kaldığı yerden devam etme, her çalışmanın `EVENT` olarak loglanması, çoklu node/dağıtık mimari.
  * *Kullanım:* Production ortamları, çoklu tenant ve yüksek güvenilirlik gereksinimi.

> **Geçiş Tetikleyicisi:**
> * Cron hata oranı son 7 günde %5+ ise → Seviye 3'e geçiş.
> * Çoklu sunucu/dağıtık mimariye geçildiğinde → Seviye 3 zorunlu.

---

### 3. MESAJLAŞMA / BİLDİRİM
**Ne işe yarar:** İnsan ve agent'lara bildirim gönderir, ekipler arası iletişim sağlar.

* **Seviye 1 — Email (SMTP)**
  * *Artıları:* Her yerde çalışır, sıfır entegrasyon.
  * *Eksileri:* Gerçek zamanlı değildir.
  * *Kullanım:* Harici müşteri bildirimleri (her zaman kalıcı kalır).
* **Seviye 2 — Slack / Teams / Telegram**
  * *Artıları:* Gerçek zamanlı iletişim, kanal ve thread desteği.
  * *Eksileri:* Dış servis bağımlılığı, agent mesajlarını izleyememe.
  * *Kullanım:* Ekipler arası iletişim ve insan odaklı bildirimler.
* **Seviye 3 — LRP Native (Phoenix PubSub + Channels) [HEDEF]**
  * *Artıları:* Agent-to-agent gerçek zamanlı mesajlaşma (HOT tier RAM üzerinde, milisaniyeler altında), her mesajın `EVENT` olarak izlenebilmesi, confidence scoring entegrasyonu, vendor bağımlılığı yok.
  * *Kullanım:* Agent mesh yapıları, kritik operasyonel bildirimler, yüksek hacimli akışlar.

> **Geçiş Tetikleyicisi:**
> * Agent-to-agent günlük mesaj hacmi 100+ ise → Seviye 3'e geçiş.
> * Ortalama mesaj gecikmesi 30sn+ ise → Seviye 3'e geçiş.
> * *Not:* E-posta harici kanallar için her zaman kalır; PubSub ise internal agent iletişimi için devreye girer. Birbirlerini yok etmez, tamamlarlar.

---

### 4. AGENT ÇALIŞTIRMA / AI ENTEGRASYONU
**Ne işe yarar:** Yapay zeka modellerini göreve koşar, kararlarını izler.

* **Seviye 1 — Manuel (İnsan)**
  * *Artıları:* Sıfır risk, tam kontrol ve güven inşası.
  * *Eksileri:* Ölçeklenemez.
  * *Kullanım:* İlk aşama ve kritik kararların manuel denetimi.
* **Seviye 2 — n8n AI Nodes / LangChain / AutoGen**
  * *Artıları:* Hazır agent kütüphaneleri, çok hızlı prototipleme.
  * *Eksileri:* Yerleşik confidence scoring yok, LRP audit trail'ine bağlanması ek geliştirme yükü, vendor lock-in.
  * *Kullanım:* Prototip ve düşük riskli operasyonlar.
* **Seviye 3 — LRP Native (AgentContext + BEAM Process) [HEDEF]**
  * *Artıları:* `confidence_score` her kararla birlikte yazılır, `reasoning_trace` (Neden bu kararı verdim?) ve `model_version` kayıt altındadır. Düşük confidence durumunda otomatik olarak insana eskalasyon yapılır. Her agent `ACTOR` tablosunda insanla eşdeğerdir; MCP tool registry entegredir.
  * *Kullanım:* Kritik kararlar, finansal işlemler, onay akışları.

> **Geçiş Tetikleyicisi:**
> * Agent kararları finansal sonuç doğuruyorsa veya audit/denetim talebi varsa → Seviye 3 zorunlu.
> * Güven (confidence) ortalaması 0.80 altına düşerse → Seviye 3'e geçiş.

---

### 5. MUHASEBE / FİNANS
**Ne işe yarar:** Çift taraflı kayıt, mali dönem kilitleri ve raporlama.

* **Seviye 1 — Excel / Google Sheets**
  * *Artıları:* Herkes bilir, kurulum gerekmez.
  * *Eksileri:* Denetim izi yoktur, çift kayıt garantisi verilemez.
  * *Kullanım:* Başlangıç aşaması (0-6 ay).
* **Seviye 2 — Logo / Luca / QuickBooks**
  * *Artıları:* VUK uyumlu, e-fatura hazır, mali müşavir dostu.
  * *Eksileri:* LRP olay akışına kördür, ayrı sistem ve mükerrer veri girişi yaratır.
  * *Kullanım:* LRP Ledger olgunlaşana kadar; shadow modda paralel izlenir.
* **Seviye 3 — LRP Native Ledger (VUK + IFRS) [HEDEF]**
  * *Artıları:* Her `EVENT` otomatik `JOURNAL` kaydı tetikler. `FISCAL_PERIOD` kilidi DB seviyesinde kontrol edilir. Değişmez (immutable) kayıtlar tutulur. VUK ve IFRS paralel olarak çalışır. `source_event_id` ile her kaydın hangi olaydan türediği bellidir. e-Defter berat entegrasyonu mevcuttur.
  * *Kullanım:* Production muhasebe, denetim süreçleri, SPK raporlamaları.

> **Geçiş Tetikleyicisi:**
> * Luca/Logo ile LRP arasındaki `discrepancy_count` 30 gün boyunca = 0 ise → Seviye 3 geçiş önerilir.
> * Denetim talebi veya IFRS raporu zorunluluğu doğarsa → Seviye 3 zorunlu.

---

### 6. DÖKÜMAN / NOT / BİLGİ TABANI
**Ne işe yarar:** Süreç belgeleri, notlar ve kurumsal bilgi bankası.

* **Seviye 1 — .md dosyası**
  * *Artıları:* Git üzerinde versiyonlanır, insan ve agent doğrudan okuyabilir.
  * *Eksileri:* Arama yeteneği zayıftır, semantik ilişkiler zordur.
  * *Kullanım:* Teknik dokümantasyon (her zaman kalabilir).
* **Seviye 2 — Notion / Obsidian (MCP ile)**
  * *Artıları:* Zengin editör desteği, MCP aracılığıyla LRP'ye bağlanabilir.
  * *Eksileri:* Bulut/harici servis bağımlılığı.
  * *Kullanım:* Ekipler arası kolaborasyon, wiki sayfaları.
* **Seviye 3 — LRP Native (OBJECT type: Document + embedding) [HEDEF]**
  * *Artıları:* `VERSION` tablosuyla versiyonlanır, agent tarafından okunabilir/yazılabilir, pgvector ile semantik arama yapılabilir, `RELATIONSHIP` tablosuyla diğer nesnelere doğrudan bağlanır (örn: "bu faturaya ait tüm dokümanlar").
  * *Kullanım:* Ajanların bilmesi gereken kritik kurumsal bilgiler.

---

### 7. VERİ PIPELINE / ETL
**Ne işe yarar:** Dış sistemlerden veri çeker, dönüştürür ve yükler.

* **Seviye 1 — CSV import / Manuel**
  * *Artıları:* Sıfır kurulum.
  * *Eksileri:* Tekrar edilemez, hata payı yüksektir.
  * *Kullanım:* İlk veri yükleme, tek seferlik aktarımlar.
* **Seviye 2 — n8n / Windmill / Airbyte**
  * *Artıları:* 300+ veri kaynağı konnektörü, görsel entegrasyon.
  * *Eksileri:* LRP olay modeline ve backpressure yapısına kördür.
  * *Kullanım:* Harici sistemlerden (örn: SAP) periyodik veri çekme.
* **Seviye 3 — LRP Native (Broadway + GenStage) [HEDEF]**
  * *Artıları:* Backpressure desteği (kapasite aşımında veri akışını yavaşlatır), her satır `EVENT` olarak izlenir, crash sonrası kalınan yerden devam edilir, çoklu consumer ve paralel işlem desteği.
  * *Kullanım:* Yüksek hacimli veri akışları, günlük 10k+ kayıt işleme.

> **Geçiş Tetikleyicisi:**
> * Günlük kayıt hacmi 10k+ olduğunda veya veri kaybı yaşandığında → Seviye 3 zorunlu.

---

### 8. ARAMA
**Ne işe yarar:** Sistem içi hızlı, typo-tolerant ve akıllı arama.

* **Seviye 1 — PostgreSQL ILIKE**
  * *Artıları:* Ekstra kurulum gerektirmez.
  * *Eksileri:* Harf hatalarına duyarsızdır (typo toleransı yok), büyük veride yavaşlar.
  * *Kullanım:* Küçük veri setleri, başlangıç fazı.
* **Seviye 2 — Elasticsearch / Meilisearch (Harici)**
  * *Artıları:* Hızlı full-text search, gelişmiş typo toleransı.
  * *Eksileri:* Ayrı servis yönetimi ve senkronizasyon yükü.
  * *Kullanım:* Büyük katalog aramaları (örn: e-ticaret).
* **Seviye 3 — LRP Native (pgvector + GIN index) [HEDEF]**
  * *Artıları:* Semantik arama ("bu faturaya benzer faturaları bul"), ayrı servis yönetimi gerektirmez (PostgreSQL içinde), agent sorguları için idealdir, nesne embedding'leri otomatik üretilir.
  * *Kullanım:* Agent retrieval işlemleri, akıllı öneriler, süreç benzerlikleri.

---

### 9. DEPOLAMA / DOSYA
**Ne işe yarar:** PDF, fatura, görsel, binary veri saklama.

* **Seviye 1 — Yerel disk / NFS**
  * *Artıları:* Basit ve hızlı.
  * *Eksileri:* Ölçeklenemez, yedekleme zordur.
  * *Kullanım:* Sadece lokal geliştirme ortamları.
* **Seviye 2 — S3 / MinIO / Cloudflare R2 [BU SEVİYEDE KALIR]**
  * *Artıları:* Sonsuz ölçeklenebilirlik, çok ucuz depolama, CDN uyumlu.
  * *Karar:* Dosya depolama her zaman dışarıda kalır. LRP veritabanında sadece `storage_key` ve `content_hash` saklanır. Seviye 3'e (core'a) geçiş anlamsızdır.

---

---

### 10. KULLANICI ARAYÜZÜ (USER INTERFACE / FRONTEND)
**Ne işe yarar:** Kullanıcının sisteme erişmesini, veri girmesini ve raporları analiz etmesini sağlar.

* **Seviye 1 — .md / CLI Arayüzü**
  * *Artıları:* Sıfır arayüz kurulumu, doğrudan Git veya terminal üzerinden kontrol.
  * *Eksileri:* Teknik olmayan kullanıcılar için uygun değildir.
  * *Kullanım:* Geliştiriciler ve sistem yöneticileri, ilk prototipleme fazı.
* **Seviye 2 — Phoenix LiveView (%80 Standart Ekranlar)**
  * *Artıları:* Sunucu merkezli (Server-rendered HTML) reaktif mimari, sıfır JS paketi, iş kuralları ve formların (`PROCESS_TASK`) inanılmaz hızlı geliştirilebilmesi.
  * *Eksileri:* Ağır veri analitiği, anlık borsa grafikleri veya milyonlarca hücrelik pivot gridlerde tarayıcı-sunucu arası ağ gecikmesi.
  * *Kullanım:* CRUD formları, onay ekranları, veri giriş arayüzleri.
* **Seviye 3 — Rust/WASM (Leptos + Perspective) [HEDEF - %20 Kritik Ekranlar]**
  * *Artıları:* Sanal DOM (Virtual DOM) kullanılmaz, doğrudan tarayıcı DOM node güncellemeleri yapılır. Apache Arrow / MessagePack binary protokolü sayesinde JSON parse yükünü sıfırlar. FINOS'un Perspective grid motoru sayesinde milyonlarca satırı tarayıcıda gecikmesiz pivotlar ve görselleştirir.
  * *Kullanım:* Ağır finansal tablolar, analitik raporlar ve canlı borsa/stok akış panelleri.

---

## 🔄 Geçiş Yönetimi Protokolü

Her capability geçişi, LRP'nin **gölge/geçiş mimarisini** kullanır:
1. Yeni sağlayıcı `PROVIDER` tablosuna eklenir (`status: "standby"`).
2. `MIGRATION_TRACKER` kaydı oluşturulur (`stage: "shadow"`).
3. Eski ve yeni sağlayıcı paralel çalışır, çıktılar karşılaştırılır.
4. `discrepancy_count = 0` ve `coverage_pct >= 80%` olduğunda IT'ye eskalasyon önerilir.
5. IT (insan) onayladığında `PROVIDER_BINDING` güncellenerek yeni sağlayıcı aktif edilir.
6. Eski sağlayıcı `deprecated` işaretlenir ama geri dönüş (downgrade) garantisi için asla silinmez.

---

## 📊 Tek Bakışta Capability Seviyeleri

| Capability | Seviye 1 (Başlangıç) | Seviye 2 (Büyüme) | Seviye 3 (LRP Native) |
| :--- | :--- | :--- | :--- |
| **Flow** | .md dosyası | n8n / Windmill | PROCESS_TASK + Oban + BEAM |
| **Cron** | Sistem cron / .sh | n8n Schedule | Oban + BEAM |
| **Mesajlaşma** | Email (SMTP) | Slack / Teams / Telegram | Phoenix PubSub + Channels |
| **Agent** | Manuel (İnsan) | LangChain / n8n AI | AgentContext + BEAM |
| **Muhasebe** | Excel / Google Sheets | Logo / Luca | LRP Ledger (VUK + IFRS) |
| **Döküman** | .md dosyası | Notion / Obsidian | OBJECT (type: Document) + pgvector |
| **ETL** | CSV Import | n8n / Airbyte | Broadway + GenStage |
| **Arama** | PostgreSQL `ILIKE` | Elasticsearch / Meilisearch | pgvector + GIN Index |
| **Depolama** | Yerel disk / NFS | **S3 / MinIO / R2 (Seviye 2'de kalır)** | — |
| **Arayüz** | .md / CLI Arayüzü | Phoenix LiveView (%80) | Rust/WASM (Leptos + Perspective) (%20) |

---

> **Değişmez Prensip:**  
> *Araç LRP'ye bağlanır, LRP araca bağlanmaz. Başlangıç her zaman en basit çözümdür, geçişler her zaman ölçüme dayalı ve kademelidir. Güvenlik, para, karar ve kimlik gibi kritik unsurlar her zaman LRP Çekirdeğinde yaşar.*

