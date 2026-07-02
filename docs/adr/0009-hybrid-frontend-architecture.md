# ADR-0009: Hybrid Frontend Architecture (Phoenix LiveView & Rust/WASM/Perspective)

- **Tarih**: 2026-07-02
- **Durum**: Kabul Edildi
- **İlişkili Kararlar**: [ADR-0001 (CQRS Read Views)](0001-cqrs-read-views.md), [ADR-0008 (Modular Data Integration)](0008-modular-data-integration-topology.md)

---

## Bağlam

Geleneksel kurumsal yazılım devleri (SAP, Oracle, Microsoft Dynamics) kullanıcı arayüzü performansında ciddi darboğazlar yaşamaktadır:
1. **SAP (Fiori/OData):** Gecikmelerin nedeni frontend render, ağ gecikmesi, SAP Gateway ve backend OData katmanları gibi çok katmanlı yapıların (DOM + JSON/REST) getirdiği yüklerdir.
2. **Oracle (Redwood):** Visual Builder ve Oracle JET bileşenlerine geçilmesine rağmen, mimari hâlâ klasik tarayıcı DOM'u ve REST API tabanlıdır.
3. **Microsoft Dynamics:** Fluent/React kütüphanelerinin paylaşımlı hale getirilmesi ("virtual controls") ile JS yükü azaltılmıştır ancak temel DOM render limitleri aşılabilmiş değildir.

LRP'nin "ışık hızında" ve veri-yoğun (fatura listeleri, pivot analizleri, büyük raporlar) ekranları kesintisiz işleme iddiası, klasik tarayıcı DOM + sanal DOM (Virtual DOM) kısıtlamalarının dışına çıkmayı gerektirir. Leptos (Rust/WASM) virtual DOM kullanmadan doğrudan DOM node'larını reaktif güncelleyerek JS framework'lerine kıyasla olağanüstü performans sağlar. Finans sektöründe kanıtlanmış Perspective (FINOS Rust/WASM) ise milyonlarca satırlık veriyi tarayıcıda sıfır gecikmeyle görselleştirebilmektedir.

Ancak tüm ekranları Rust ile yazmak geliştirme hızını düşürecek ve geliştirici havuzunu daraltacaktır. Bu nedenle hibrit bir arayüz mimarisine ihtiyaç vardır.

---

## Karar

LRP kullanıcı arayüzü (Surface Builder / Storefronts / Admin Panels) için **Hibrit Ön Yüz Mimarisi (Hybrid Frontend Architecture)** kabul edilmiştir:

```
PostgreSQL (CQRS Read View / Materialized Table)
        ↓
Elixir + Phoenix (Contexts, Transactions, Oban Jobs, Channels/PubSub)
        ↓
[ Phoenix Channels / WebSockets (Binary MsgPack / Arrow) ]
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

1. **%80 İş Akışı ve Standart Form Ekranları (Phoenix LiveView):**
   * CRUD formları, onay süreçleri (`PROCESS_TASK`) ve standart veri giriş ekranları Phoenix LiveView ile geliştirilir.
   * Sunucu merkezli reaktif arayüz sayesinde iş kuralları çok hızlı itere edilir, JS yazma gereksinimi en aza indirilir.
2. **%20 Performans-Kritik Analiz ve Raporlama Ekranları (Rust/WASM - Leptos + Perspective):**
   * On binlerce satırlık veri gridleri, pivot tablolar, canlı borsa/stok veri akışları ve grafik görselleştirmeleri Rust/WASM tabanlı **Leptos** ve **Perspective** motoruyla sunulur.
   * Bu ekranlar veriyi binary protokol (MessagePack veya Apache Arrow) üzerinden çekerek JSON parse yükünü tamamen ortadan kaldırır.
3. **Virtual DOM'un Tamamen Devre Dışı Bırakılması:**
   * Leptos reaktif güncelleme modeliyle virtual DOM fark (diff) hesaplama adımlarını atlayarak doğrudan ilgili tarayıcı node'larını günceller.

---

## Sonuçlar

### Olumlu (Pros)
- **Native Arayüz Hızı:** Ağır raporlama ve veri analiz ekranlarında SAP/Oracle/Dynamics'e kıyasla 10x-50x daha hızlı render performansı elde edilir.
- **Düşük Ağ ve İşlemci Yükü:** JSON yerine binary formatlar kullanılarak tarayıcı işlemcisinin ve ağ bant genişliğinin yorulması engellenir.
- **Hızlı Ürünleştirme:** Standart formlar LiveView ile gün/saat mertebesinde hızlıca yazılırken, yüksek mühendislik bütçesi yalnızca performans gerektiren kritik ekranlara harcanır.

### Riskler / Dikkat (Cons)
- **Yetenek Havuzu Darboğazı:** Rust/WASM ve Leptos bilen geliştirici sayısı kısıtlıdır; bu nedenle bu ekranların sınırları katı çizilmeli ve standart LiveView ile karıştırılmamalıdır.
- **Derleme ve Dağıtım Süresi:** Rust WebAssembly derleme süreleri LiveView'a göre uzundur; CI/CD hatlarında WASM derleme adımları optimize edilmelidir.
