# LRP — Ön Yüz Stratejisi (Frontend Strategy)
*Kurumsal Devlerin UI Hataları, Rust/WASM Performansı ve Hibrit Arayüz Mimarisi.*

---

## 1. Giriş
Geleneksel ERP ve CRM yazılımları (SAP, Oracle, Microsoft Dynamics) arayüz hızı ve veri yoğun ekranların yönetimi konusunda ciddi yapısal sınırlar ve darboğazlar yaşamaktadır. LRP, bu kısıtlamaları aşmak ve "ışık hızında" bir kullanıcı deneyimi sunmak için modern web teknolojilerini yenilikçi bir mimariyle birleştirir.

---

## 2. Legacy ERP Arayüzlerinin Darboğaz Analizi

### SAP Fiori & OData
* **Kusuru:** SAP resmi performans teşhis belgelerinde de kabul edildiği üzere, yavaşlığın kaynağı tek bir bileşen değildir. Ağ gecikmesi, OData XML/JSON ayrıştırma (parsing) yükleri, SAP Gateway katmanı ve tarayıcı DOM render süreçleri bir araya gelerek genel deneyimi hantallaştırır. 
* **Zihinsel Model:** UX sonradan yamamıştır; altyapı hâlâ 1990'ların ABAP transaction tabanlı zihniyetini taşır.

### Oracle Redwood (Visual Builder & JET)
* **Kusuru:** Eski ADF mimarisinden Oracle JET (JavaScript Extension Toolkit) ve Visual Builder Studio yapısına geçilmiştir. Ancak bu yaklaşım da temel olarak tarayıcı DOM'u, JavaScript yürütümü ve klasik REST/JSON modeline dayanır.
* **Zihinsel Model:** Tasarım modernleştirilmiş olsa da ağaç yapısı ve veri akış biçimleri geleneksel kalmıştır.

### Microsoft Dynamics 365 & Power Apps
* **Kusuru:** Microsoft, her bileşenin kendi React ve Fluent kütüphanesini paketlemesinin yarattığı devasa JS dosyalarını engellemek için "virtual control" modeline geçmiştir. Platformda yüklü olan React/Fluent kütüphaneleri paylaşılarak JS boyutu düşürülmüştür.
* **Zihinsel Model:** Excel tabanlı satır/sütun zihniyeti baki kalmıştır; tarayıcı tarafındaki sanal DOM diff (fark) algoritmaları büyük veri setlerinde tıkanır.

---

## 3. Neden Rust ve WebAssembly (WASM)?

Rust/WASM tabanlı modern frontend framework'leri (örn. **Leptos**, **Dioxus**), React ve benzeri geleneksel kütüphaneleri performans testlerinde (js-framework-benchmark) geride bırakır.

1. **Virtual DOM'suz Reaktif Çizim (Leptos Modeli):**
   Leptos, sanal bir DOM (Virtual DOM) ağacı tutmaz. Bunun yerine, bir reaktif değişken değiştiğinde tarayıcıdaki tek bir metin node'unu veya class'ı doğrudan (fine-grained) günceller. Diff/hesaplama aşamalarını atladığı için framework'süz JavaScript hızına en yakın performansı verir.
2. **Binary Veri Taşıma Protokolü (MsgPack/Arrow):**
   Ağır veri tablolarında JSON string parsing işlemcileri çok yorar. Rust/WASM, **MessagePack** veya **Apache Arrow** gibi binary protokolleri tarayıcı tarafında doğrudan deserialize edebilir.
3. **Perspectives (FINOS):**
   Finansal borsa ve veri analiz şirketleri (FINOS) tarafından geliştirilen ve Rust/WASM tabanlı olan **Perspective** grid motoru, milyonlarca satırlık veriyi tarayıcıyı dondurmadan anlık pivotlama, filtreleme ve grafikleme gücü sunar.

---

## 4. LRP Hibrit Ön Yüz Mimarisi (Hybrid UI)

Teknik olarak tüm ekranları Rust ile yazmak yüksek performans getirse de, iki önemli risk barındırır:
* **Geliştirici Havuzunun Dar olması:** Rust/WASM bilen frontend geliştiricisi bulmak zordur.
* **Geliştirme Hızının Düşmesi:** Basit CRUD formlarında Rust'ın katı tip kontrolü ve derleme süreleri iterasyon hızını yavaşlatır.

LRP bu engeli aşmak için **Hibrit Yaklaşım (80/20 Kuralı)** uygular:

```
PostgreSQL (CQRS Read View)
        ↓
Elixir + Phoenix (İş mantığı, Oban, Channels/PubSub)
        ↓
[ Phoenix Channels / WebSockets (Binary Protokol) ]
        ↓
┌───────────────────────────────────────┐
│              SURFACE UI               │
├───────────────────┬───────────────────┤
│    %80 Ekranlar   │    %20 Ekranlar   │
│ (İş Akışı/Form)   │ (Rapor/Pivot/Grid)│
│  ───────────────  │  ───────────────  │
│ Phoenix LiveView  │ Rust/WASM Leptos  │
│  (Hızlı Geliş.)   │  + Perspective    │
└───────────────────┴───────────────────┘
```

### %80 Ekranlar: Phoenix LiveView
İş akışları, onay süreçleri (`PROCESS_TASK`), veri giriş formları ve standart CRM/ERP listeleri Phoenix LiveView ile sunucu merkezli reaktif olarak yazılır. JS yazma yükü sıfıra yakındır ve iş kuralları çok hızlı güncellenir.

### %20 Ekranlar: Rust/WASM (Leptos + Perspective)
Milyonlarca satırlık stok analizleri, finansal konsolidasyon tabloları, pivot raporlar ve canlı akış panelleri Rust/WASM ile client-side render edilir.

### Kullanıcı Tanımlı Ekranlar: space-agent Entegrasyonu
LRP çekirdek uygulamaları yerleşik olarak bu yüksek performanslı mimariyle gelirken, son kullanıcıların veya entegratörlerin kendi özel ekranlarını, panellerini ve arayüzlerini özgürce tasarlayabilmesi için [space-agent](https://github.com/agent0ai/space-agent) entegrasyonu standart olarak sunulur. Bu sayede kullanıcılar, LRP çekirdek koduna dokunmadan kendi dinamik ekranlarını inşa edebilir ve LRP API'leri ile doğrudan konuşturabilir.

---

## 5. Uygulama ve Geçiş Tetikleyicileri

Bir capability veya ekranın LiveView'dan Rust/WASM katmanına taşınması aşağıdaki kriterlere bağlıdır:

* **Sayısal Yoğunluk:** Tek ekranda gösterilecek veya işlenecek satır sayısı > 10.000 ise.
* **Ağ Darboğazı:** JSON parse süresi tarayıcı tarafında 200ms üzerine çıkıyorsa (binary veri taşıma tetiklenir).
* **Görsel Çakışma ve Hesaplama:** Tarayıcı tarafında karmaşık pivot analizi ve gerçek zamanlı dinamik filtreleme gerekiyorsa.

---

*Bu strateji, LRP'nin teknik dayanıklılık felsefesinin (Resiliency Principles) ve rekabet konumlandırmasının arayüz katmanındaki somut karşılığıdır.*
