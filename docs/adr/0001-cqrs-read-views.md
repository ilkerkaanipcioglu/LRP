# ADR 0001: CQRS Read Views for Object Graph EAV Performance

*   **Durum:** Kabul Edildi
*   **Tarih:** 2026-06-30
*   **Yazar:** Antigravity Mimar

---

## 1. Bağlam (Context)

LRP'nin jenerik "Everything is an Object" (EAV + JSONB) tasarımı kurumsal esneklik sağlasa da, production ortamında sorgulama ve raporlama katmanında (BI, finansal mutabakat vb.) ciddi performans bedelleri ödetmektedir. Klasik EAV yapısında "bu ayki vadesi geçmiş faturaları listele" gibi basit bir iş sorgusu dahi 4-5 join'e ve karmaşık JSONB index taramalarına dönüşmektedir.

---

## 2. Karar (Decision)

Bu performans ve sorgu karmaşıklığı sorununu aşmak için **CQRS (Command Query Responsibility Segregation)** ve **Materialized Read Models** yapısı benimsenecektir:

1.  **Write Path (Yazma):** Nesne grafiği (9 jenerik tablo) üzerinde esnek, normalize ve tutarlı (strongly consistent) olarak çalışmaya devam edecektir.
2.  **Read Path (Okuma/Raporlama):** `Event` akışını ve nesne güncellemelerini dinleyen asenkron consumer'lar (Broadway / GenStage), raporlama için optimize edilmiş düzleştirilmiş **Read Model tabloları** (örneğin: `InvoiceView`, `CustomerView`, `InventoryView`) üretecektir.

### 2.1 Staleness (Gecikme) Sözleşmesi
- Asenkron read model tablolarının yazma anından itibaren gecikme süresi **maksimum 5 saniye (eventual consistency)** olarak taahhüt edilir. Raporlama ve arama ekranları bu 5 saniyelik gecikmeyi kabul eder.
- **Stale Read Koruması:** Fatura onayı, ödeme tetiklemesi veya stok çıkışı gibi kritik ve sıfır gecikme (strong consistency) gerektiren karar/onay anlarında, sistem asenkron Read View'ları sorgulamayacaktır. Bu kararlar doğrudan write-path üzerindeki `OBJECT` ve `EVENT` tablolarından anlık tutarlı sorgularla (strongly consistent read) yürütülecektir.

---

## 3. Değerlendirilen Alternatifler (Alternatives)

*   **Alternatif A: Direct Database Views (Veritabanı Görünümleri):** 9 tablo üzerinde SQL view tanımlamak. JSONB sorgu yavaşlığını çözmediği ve her sorguda CPU'ya yük bindiği için reddedildi.
*   **Alternatif B: Klasik ERP Somut Şeması:** Her modül (CRM, İK vb.) için yeni tablolar ve kolonlar açmak. AI ajanlarının kendi kendine veri şeması üretmesini ve platformun jenerik genişletilebilirliğini engellediği için reddedildi.

---

## 4. Sonuçlar ve Riskler (Consequences)

*   **Olumlu:** Raporlama ve arama sorguları milisaniyeler içinde düz tablolar üzerinden dönecektir. AI ajanları şemayı kirletmeden esnek yazma yapmaya devam edebilir.
*   **Negatif/Risk:** Nihai tutarlılık (eventual consistency) nedeniyle kullanıcı arayüzlerinde veya raporlarda çok kısa süreli (max 5sn) gecikmeler yaşanabilir. Bu durum UI katmanında optimistik güncellemelerle çözülecektir.
