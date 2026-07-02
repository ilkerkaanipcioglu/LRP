# LRP — Pazar Konumlandırması ve Rekabet Analizi
*Legacy ERP devlerinin çuvalladığı yerler ve LRP'nin getirdiği çözümler.*

---

## 🏢 Legacy Sistemlerin Çıkmazları ve LRP Çözümleri

### 1. SAP (Sistem Entegrasyon Cehennemi)

| Müşteri Acısı (SAP Failure) | LRP Çözümü (LRP Solution) |
| :--- | :--- |
| **Kurulum = Bitmeyen Proje:** SAP kurulumları 6-18 ay süren, ABAP özelleştirmeleri, transport request'ler, basis kurulumları içeren devasa danışmanlık projeleridir. Entegratör ekosisteminin çıkarına hizmet eder. | **Tek Komutla Ayakta:** LRP kurulumu sıfırdan 5 dakika sürer. <br>`curl setup.sh \| bash && mix lrp.demo` komutu ile uçtan uca canlı demo anında hazırdır. |
| **Hantal Veri Modeli Değişikliği:** Yeni bir özel alan (örn. segment kodu) eklemek enhancement spot'lar, user-exit'ler, transport'lar ve downtime gerektirir. | **Esnek Şema:** `OBJECT.metadata` içindeki JSONB yapısı sayesinde yeni alanlar deploy veya migration gerektirmeden anında kullanılabilir. |
| **Raporlama Ayrı Ürün (BW/BObj):** Operasyonel veri ile raporlama verisi aynı yerde yaşamaz. Ayrı lisanslar, ayrı ekipler ve ETL süreçleri gerektirir. | **Dahili CQRS:** Yazma işlemleri generic Object Graph'te yapılırken, raporlama/okuma işlemleri materialized view'lar üzerinden join gerektirmeden anında çözülür. |
| **1990'lardan Kalma Kullanıcı Arayüzü:** SAP GUI hâlâ yaygındır. Fiori modern görünse de altında aynı eski transaction kodları çalışır. UX sonradan yamamıştır. | **Surface Builder:** Kullanıcılar çekirdek koda hiç dokunmadan kendi ekranlarını esnekçe tasarlar. |
| **Yama Yapay Zeka (Fake AI):** AI özellikleri sisteme gömülü değildir; harici bulut servisleri ve ek lisanslarla sisteme yapıştırılır. | **Agent-Native Çekirdek:** AI Agent'lar, `ACTOR` tablosunda insanlar ile aynı seviyede birinci sınıf vatandaş olarak modellenmiştir. |

---

### 2. Odoo (Kararsız Modülerlik)

| Müşteri Acısı (Odoo Failure) | LRP Çözümü (LRP Solution) |
| :--- | :--- |
| **Modüller Birbirini Bozar:** Bir modülün güncellenmesi diğerini kırabilir. Özelleştirilmiş Odoo sistemleri sürüm güncellemeleriyle kilitlenir; güncelleme yapılamaz hale gelir. | **Modülsüz Mimarî:** Sistem modüllerden değil, evrensel `OBJECT`, `EVENT` ve `RELATIONSHIP` yapısından oluşur. Tip eklemeleri diğer akışları etkilemez. |
| **Python ORM Performansı:** Odoo ORM'i karmaşık sorgularda çok yavaş SQL'ler üretir. Fatura listeleri gibi büyük veri setleri ekran yüklemelerini dakikalara çıkarabilir. | **Okuma/Yazma Ayrımı:** CQRS yapısı ve materialized view'lar sayesinde listeleme ekranları düz tablolardan, join yapılmadan saniyeler altında getirilir. |
| **Uygulama Seviyesinde İzolasyon:** Multi-company veri izolasyonu uygulama katmanında (Python koduyla) yapılır. Bir `WHERE` filtresi unutulduğunda veriler birbirine sızabilir. | **PostgreSQL RLS (Row-Level Security):** Tenant ve şirket izolasyonu doğrudan veritabanı motoru seviyesinde zorlanır; kod hatası olsa bile sızıntı imkansızdır. |
| **Katı ve Sabit Workflow'lar:** Onay akışları modüllerin içine kodlanmıştır. "Onaycı tatildeyse yedek onaycıya geç" gibi dinamik kurallar ağır özelleştirme gerektirir. | **PROCESS_TASK & State Machine:** Onay ve iş akışları yazılım kodu değil, dinamik olarak yorumlanıp işletilen konfigürasyonlardır. |

---

### 3. Oracle (Lisans Silahı)

| Müşteri Acısı (Oracle Failure) | LRP Çözümü (LRP Solution) |
| :--- | :--- |
| **Lisanslama Baskısı (Audit):** Core sayıları, aktif edilen özellikler ve sanallaştırma kuralları kasıtlı olarak karmaşık tutulur. Audit'ler müşterileri yüksek faturalarla cezalandırır. | **Açık Kaynak Çekirdek:** LRP protokolü açık kaynaklıdır. Sistem ölçeklendirmesi yapay lisans duvarlarıyla değil, altyapı maliyetiyle sınırlıdır. |
| **"Lift and Shift" Bulut Geçişi:** Oracle bulut geçişleri modernizasyon sunmaz; eski monolitik yapıların sadece bulut sunucularına taşınması (lift and shift) düzeyindedir. | **Bulut-Native Mimari:** Sistem en baştan event-driven ve dağıtık olarak tasarlandığından buluta taşınma mimari değil, sadece deploy değişikliğidir. |
| **Entegrasyon Middleware Bağımlılığı:** Oracle sistemlerini bağlamak için Oracle SOA Suite veya Integration Cloud gibi pahalı ve tescilli middleware ürünleri zorunludur. | **Standart CONNECTOR Arayüzü:** Herhangi bir dış sisteme, ortak entegrasyon kontratı üzerinden doğrudan bağlanır. Harici middleware gerektirmez. |

---

### 4. Microsoft Dynamics (Excel Bağımlılığı)

| Müşteri Acısı (Dynamics Failure) | LRP Çözümü (LRP Solution) |
| :--- | :--- |
| **Dynamics = Excel Kardeşliği:** Microsoft'un zihinsel modeli hâlâ tablo/satır/sütun tabanlıdır. Karmaşık ilişkileri ifade edemediği için veriler eninde sonunda Excel'e aktarılır. | **Graf-First (Graph-Native):** İlişkiler sistemde birinci sınıf vatandaştır. `RELATIONSHIP` tablosu en az `OBJECT` kadar önemlidir ve semantik bağıntıları çözebilir. |
| **Power Platform Lock-In:** "Low-code" olarak pazarlanan Power Automate ve Power Apps akışları tamamen Microsoft ekosistemine kilitlenir. Başka sisteme taşınamaz. | **Açık Standart Ekranlar:** Surface Builder ekranları standart LiveView bileşenleri veya açık JSON spec formatında tutulur, üretici kilitlenmesi (lock-in) yoktur. |
| **Tek Noktada Bağımlılık (Teams):** Dynamics bildirimleri ve onay süreçleri tamamen Teams üzerine kurgulanmıştır. Teams yavaşladığında veya çöktüğünde iş akışı durur. | **CONNECTOR Hot-Swap:** Bildirim ve onay kanalları (Slack, Telegram, email, Teams) core sisteme dokunulmadan anında değiştirilebilir. |
| **Azure Zorunluluğu:** Dynamics bulut özellikleri Microsoft Azure dışında tam performansla çalıştırılamaz. Bulut seçeneği kısıtlıdır. | **Her Yerde BEAM:** Elixir/BEAM altyapısı standart herhangi bir Linux/Unix sunucuda, OVH'da, AWS'te, GCP'de veya yerel sunucularda tamamen aynı kararlılıkla çalışır. |

---

### 5. Kullanıcı Arayüzü & Render Performansı (UI & Rendering Performance)

| Rakip Sistem | Mimari Yaklaşım & Darboğaz | LRP Hibrit Ön Yüz Çözümü |
| :--- | :--- | :--- |
| **SAP (Fiori):** | Ağ gecikmesi, SAP Gateway/OData parse yükü ve tarayıcı DOM manipülasyonları nedeniyle performans teşhisinde darboğaz tespiti zordur. | **Virtual DOM'suz Render (%20 Leptos):** Kritik ekranlarda sanal DOM diff mekanizmasını atlayarak tarayıcı node'larını doğrudan reaktif günceller. |
| **Oracle (Redwood):** | Eski ADF'den JET ve Visual Builder'a geçilse de, hâlâ tarayıcı + JS + klasik REST/JSON modeline dayanır. | **Binary Protokol (MsgPack/Arrow):** Ağır raporlama ve analiz verilerini JSON yerine binary formatlarda taşıyarak parse süresini sıfırlar. |
| **Microsoft Dynamics:** | Virtual control'ler ile paylaşımlı React/Fluent kütüphaneleri kullanarak JS boyutunu azaltmıştır; ancak DOM render limitleri baki kalmıştır. | **Dahili Finansal Grid (Perspective):** FINOS'un finans sektörü için geliştirdiği Rust/WASM tabanlı grid motorunu kullanarak milyonlarca satırı sıfır gecikmeyle pivotlar. |
| **Geliştirme Hızı:** | Ağır ABAP/ADR geliştirmeleri veya PowerApps kilitlenmeleri. | **Dengeli Hibrit Yaklaşım:** Formlar ve iş akışları (%80) Phoenix LiveView ile sunucu merkezli hızlıca yazılırken, ağır ekranlar (%20) Rust/WASM ile optimize edilir. |

---

## 🏆 Ortak ve En Büyük Çıkmaz: Verinin Rehin Alınması (Vendor Lock-In)

Dev ERP sağlayıcılarının (SAP, Oracle, Microsoft) en büyük ortak kusuru **kasıtlı vendor bağımlılığıdır**:
* SAP'tan veri ayıklamak için SAP danışmanı kiralamanız gerekir.
* Oracle'dan ham veri çekmek ve raporlamak için lisans duvarlarını aşmanız gerekir.
* Dynamics'ten veri export etmek Microsoft'un kapalı şemalarına uymayı gerektirir.

> **LRP'nin Özgürlük Bildirgesi:**
> *Veriniz her zaman size aittir. `OBJECT` ve `EVENT` standart, açık veri formatlarında depolanır. Dışa aktarma (export) her zaman mümkündür. Sağlayıcıyı değiştirseniz bile veriniz elinizde kalır, sisteminizin kontrolü sizde olur.*

---

*Bu analiz, LRP'nin pazara çıkış ve satış argümanlarının (Value Proposition) teknik ve felsefi temelini oluşturur. LRP ekosistemindeki tüm ajans ve geliştiriciler, sistemi satarken ve konumlandırırken bu rekabetçi farkları ön planda tutar.*
