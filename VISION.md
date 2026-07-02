# LRP — Vision

> **"An AI-native Enterprise Operating System where every business object is an entity,
> every change is an event, every workflow is explainable,
> and every decision can be delegated to humans or AI agents."**

---

## Where We're Going

```
ERP is not software.
ERP is a knowledge graph.

Everything is an entity.
Everything is an event.
Everything is traceable.
Everything is explainable.
```

### Why LRP?

| System | Paradigm             |
| ------ | -------------------- |
| SAP    | Transaction driven   |
| Odoo   | Module driven        |
| LRP    | **Knowledge driven** |

---

## 🎯 LRP'nin İnşa Felsefesi (10 Temel Prensip)

LRP, geleneksel "modern best practice" listeleriyle değil, doğrudan gerçek dünya deneyimlerinden süzülmüş 10 temel inşa prensibi üzerine kurulmuştur:

1. **Tek Varlık Kaydı (Her Şeyin Temeli)**: Bir müşteri/cari CRM'de, ERP'de, e-ticarette veya muhasebede ayrı tablolarda saklanmaz. Tek bir ortak `OBJECT` (Party) kaydı vardır ve tüm sistemler bu tek kaydı görür. Bu sayede entegrasyon cehennemi baştan engellenir.
2. **Her Değişiklik Bir Olay (Güncelleme/Silme Yok)**: Hiçbir veri doğrudan `UPDATE` veya `DELETE` ile ezilmez. Sipariş iptali mi oldu? "İptal edildi" olayı yazılır. Fiyat mı değişti? "Fiyat değişikliği" olayı yazılır. 6 ay sonra "buna ne oldu, kim ne yaptı" sorusu her zaman kesin olarak cevaplanabilir.
3. **Kim Yaptı? (İnsan mı, Sistem mi, Agent mı?)**: Her işlemde üç şey zorunlu ve değişmezdir: *kim yaptı*, *ne zaman yaptı*, *neden yaptı*. Ajan (AI Agent) yaptıysa hangi modelle, hangi güven skoru (`actor_confidence`) ve hangi karar zinciriyle (`reasoning_trace`) yaptığı kayıt altına alınır.
4. **Para Her Zaman Çift Taraflı (Double-Entry)**: Finansal her hareket için çift giriş (debit/credit) zorunludur. Tek sütun "amount" ile para takibi yapılmaz; para bir yerden çıkıyorsa diğer yere girer ve ikisi birden `JOURNAL_LINE` olarak yazılır.
5. **DB Seviyesinde Dönem Kilidi**: Belirli bir mali dönem (örn. Ocak) kapandıktan sonra o döneme hiçbir şey yazılamaz. Bu kural uygulama koduyla değil, doğrudan veritabanı/şema kısıtlarıyla (`FiscalPeriod` kilitleri) korunur.
6. **Gerçek Arama**: Arama sadece isim eşleşmesiyle sınırlı değildir. Geçmiş siparişler, e-postalar, notlar ve faturalar full-text search ve semantik arama (`OBJECT.embedding`) ile baştan planlanmış bir bütün olarak sorgulanabilir.
7. **İş Akışlarında Pause/Resume Desteği**: Bir süreç (örn. fatura onayı) yetkili tatile gittiğinde donmaz veya iptal olmaz. Duraklayıp, yetkili döndüğünde kaldığı yerden devam edebilen state machine tabanlı `PROCESS_TASK` yapısıyla çalışır.
8. **Stratejik Bildirim Katmanı**: "Her değişiklikte mail at" gibi spam yaklaşımları yerine; neyin, kime, hangi kanaldan (email/Slack/push) ve ne sıklıkla özetleneceğini bilen ayrışmış bir `EVENT_SUBSCRIPTION` ve bildirim katmanı vardır.
9. **Önce API, Sonra Arayüz**: Her özellik önce API olarak tasarlanır ve çalışır, arayüz ise bu API'nin üzerine kurulur. Bu sayede mobil uygulamalar, 3rd party entegrasyonlar ve AI agent'lar sistemi yeniden yazmaya gerek kalmadan doğrudan tüketebilir.
10. **Veritabanı Seviyesinde Tenant İzolasyonu**: Kiracılar (Tenants) ve kullanıcılar arası erişim yetkileri uygulama koduna güvenilerek değil, doğrudan veritabanı seviyesinde Row-Level Security (RLS) politikalarıyla kesin olarak ayrılır.

Bu prensipler belirli bir modüle (CRM, ERP, e-ticaret) özel değildir; veriyi doğru tutan, geçmişi kaybetmeyen ve büyüdükçe çürümeyen bir sistemi inşa etmenin tek yoludur.

---

## 🛡️ LRP'nin Dayanıklılık Prensipleri (15 Mühendislik Kuralı)

LRP, yalnızca ayakta duran bir sistem değil, aynı zamanda çökmeyen, ölçeklenebilir ve dağıtık ortamlarda kusursuz çalışan dayanıklı (resilient) bir mimari hedefler. Bu hedefin 15 temel mühendislik kuralı şunlardır:

1. **Şema-Uygulama Ayrımı (Migration Krizlerine Son)**: Veri modeli değiştiğinde sistem durmamalıdır. JSONB + dinamik tip sistemi sayesinde yeni bir alan eklemek downtime veya deploy gerektirmez. "Sütun eklemek için 2 saatlik bakım penceresi" kabul edilemez.
2. **CQRS (Okuma ve Yazma Hatlarının Ayrılması)**: Yazma hattı kesin, tutarlı ve yavaş olabilir; okuma hattı ise hızlı, önbelleğe alınmış ve hafif eski (stale) olabilir. Dashboard sorguları ile fatura yazma işlemleri aynı veritabanı bağlantısını ve kaynağını tüketmez.
3. **Asenkron Olay Akışı (Sıkı Bağların Çözülmesi)**: Servisler birbirini doğrudan çağırmaz (`OrderService.create()` içinde `InvoiceService.generate()` çağrılmaz). Bir `order_created` event'i yayınlanır; fatura servisi bunu dinler ve kendi hızında işler. Servisler bağımsız ölçeklenir ve çöker.
4. **Circuit Breaker (Zincirleme Çöküş Engelleyici)**: Dış servisler (ödeme, kargo, e-fatura) yavaşladığında veya çöktüğünde tüm sistemi dondurmaz. Belirlenen hata eşiği aşıldığında bağlantı otomatik kesilir (OPEN), hata dönülür ve servis düzeldiğinde tekrar otomatik bağlanır (CLOSED).
5. **Distributed Tracing (Uçtan Uca Takip)**: "Sipariş tamamlandı ama fatura oluşmadı" gibi dağıtık sistem hatalarını çözmek için, isteğin girdiği andan çıktığı ana kadar olan tüm logları bağlayan tek bir benzersiz `trace_id` kullanılır.
6. **Mutlak Idempotency**: Ağ kesintisi veya mükerrer tıklamalarda sistem aynı isteğe her zaman aynı yanıtı vermelidir. Çift sipariş veya çift ödeme oluşmasını engellemek için `idempotency_key` mimarinin zorunlu bir parçasıdır.
7. **Event Sourcing (Geriye Sarma / Playback)**: Sistemdeki tüm durum (state), sıfırdan event log akışı baştan oynatılarak (replay) yeniden hesaplanabilir. Bu hem felaket kurtarma (disaster recovery) hem de geriye dönük denetim için nihai güvencedir.
8. **BEAM/Erlang Süpervizör Ağacı (Supervisor Trees)**: Her işlem izole, küçük bir process olarak çalışır. Çöken bir process, tüm sistemi etkilemeden kendi supervisor'ı tarafından anında yeniden başlatılır. Yüksek erişilebilirlik (nine-nines availability) bu mimarinin doğal sonucudur.
9. **Sıfır Downtime Deploy (Zero-Downtime)**: Yeni sürümler yayına alınırken eski versiyonla paralel çalışır ve trafik kademeli olarak kaydırılır (canary/blue-green). Kullanıcı hiçbir zaman "bakım modu" ekranı görmez.
10. **Otomatik Veri Sıkıştırma ve Katmanlama (Data Tiering)**: Veriler zaman bazlı politikalarla otomatik olarak katmanlanır. Sıcak veri (son 30 gün) hızlı RAM/SSD katmanında saklanırken, ılık veri (1 yıl) standart disklerde, soğuk arşiv verisi ise ucuz bulut depolamada saklanır.
11. **Schema Registry (Event Versiyonlama)**: Event formatları değiştiğinde consumer'ların kırılması engellenir. Her event tipinin versiyonlu şeması (`order_created_v1`, `order_created_v2`) kayıt altında tutulur ve geriye dönük uyumluluk korunur.
12. **Mimaride Backpressure Desteği**: Sisteme kapasitesinin üzerinde yük bindiğinde veriyi sessizce yutmak yerine backpressure ile yükü sıraya alır veya kontrollü olarak reddeder. Broadway ve GenStage entegrasyonu LRP'nin doğal bir parçasıdır.
13. **CRDT (Çakışmasız Dağıtık Durum)**: Dağıtık sistemlerde aynı kayda yapılan çakışan güncellemeler "son yazan kazanır" şeklinde ezilmez. CRDT'ler (Conflict-free Replicated Data Types) sayesinde sayaçlar, stok miktarları ve onay durumları matematiksel olarak birleştirilir.
14. **Gözlemlenebilirlik Üçlüsü (Metrics, Logs, Traces)**: Sistem durumu üç boyutta eşzamanlı izlenir: anlık durum metrikleri, detaylı olay logları ve uçtan uca istek izleri (traces). Biri eksikse production ortamında kör uçuş yapılıyor demektir.
15. **Chaos Engineering (Kontrollü Kırılma)**: Sistem dayanıklılığını test etmek için üretim/sahne ortamında rastgele servisler durdurulur, ağ gecikmeleri ve sahte disk dolulukları oluşturularak (Chaos Monkey mantığı) sistemin hata kurtarma davranışı sürekli test edilir.

> **LRP ile Bağlantı:** Bu 15 prensibin 8'i (Event Sourcing, Idempotency, BEAM Supervisor, Backpressure, CQRS, Tracing altyapısı, Schema Versioning, CONNECTOR circuit breaker) LRP mimarisinin temelinde yerleşik olarak mevcuttur. Kalan 7 kural (CRDT, Chaos Engineering, Schema Registry, Otomatik Data Tiering, Sıfır Downtime Deploy, Observability Stack, Conflict Resolution) ise mevcut LRP felsefesiyle tam uyumludur ve adım adım üstüne inşa edilmektedir.

---

## The Full Vision

### 1. Everything is an Entity

Every business concept — Customer, Vendor, Contract, Document, AI Agent, Invoice — is a
generic `OBJECT`. Roles (Customer, Vendor, Employee) are added dynamically. No separate
tables per module. The schema never changes; the knowledge graph grows.

### 2. Everything is an Event (Event Sourcing)

There are no `UPDATE` or `DELETE` commands in LRP. Every state change emits an append-only event:

```
EntityCreated / EntityChanged / StockMoved / InvoicePosted / PaymentReceived
```

Current state (Current Stock, Current Balance) is always derived from projections over the
event stream — never from a mutable row.

### 3. Everything is Traceable (Full Audit)

When fully realized, every HOT/WARM/COLD event is durably committed before acknowledgment.
Every JOURNAL_LINE links back to `source_event_id` → `POSTING_RULE` → triggering `EVENT`,
creating a single unbroken audit chain from business event to ledger entry across all
GAAP schemes (VUK, IFRS, SPK).

### 4. Everything is Explainable (AI + Ledger)

When an AI agent makes a recommendation or a ledger entry is questioned, the system must
answer *why*:

```
Invoice amount = X
Because: Posting Rule #42 applied to event "InvoiceApproved"
Source event payload: { supplier_score: 0.8, delivery_delay: 2d }
Ledger: VUK | Account: 320 → 100
```

Explainability spans both the Object Graph (AI reasoning trace) and the Ledger
(posting rule + event provenance).

### 5. AI as Runtime, Not Feature

AI is not an assistant tab. It runs inline at every operation:

```
entity.create() → AI Validation → Duplicate Detection → Risk Scoring → Workflow Suggestion → Save
```

### 6. Agent Router at the Core

```
Request → Classifier → Cheap Model → Reasoning Model → Local LLM → External LLM
```

---

## Implementation Stages

| Version | Milestone           | Status     |
| ------- | ------------------- | ---------- |
| v0.1    | Entity Engine       | ✅ Done     |
| v0.2    | Workflow Engine     | ✅ Done     |
| v0.3    | Ledger (VUK + IFRS) | ✅ Done     |
| v0.4    | AI Router           | 🔲 Planned |
| v0.5    | Agent Framework     | 🔲 Planned |
| v0.6    | Plugin SDK          | 🔲 Planned |
| v1.0    | Production Ready    | 🔲 Planned |

> This is a vision document — it describes where LRP is going, not where it is today.
> For current capabilities and honest implementation status, see [README.md](README.md).
