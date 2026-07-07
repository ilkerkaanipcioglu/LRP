# LRP Frontend Demo & space-agent Positioning

Bu dizin, **LRP (Lightweight Resource Planning)** protokolü üzerinde geliştirilen veya geliştirilmesi planlanan raporların, ekranların ve iş akışlarının ön yüz şablonlarını (Frontend Templates) barındırır. 

Buradaki temel amaç; **henüz arka plan (backend) iş mantığı kodlanmadan önce** kullanıcıların ve müşterilerin etkileşime girebileceği, indirebileceği veya paylaşabileceği tam uyumlu arayüz prototiplerini (mock-ups) hızlıca üretmektir.

---

## 📂 Şablon Türleri (Templates)

LRP veri sözleşmeleri (Object/Event yapısı), arayüz katmanından tamamen bağımsız olduğu için sistem farklı ön yüz dillerini destekleyecek şekilde konumlandırılmıştır:

1.  **[SAP_GUI](file:///B:/DEV/HAREZM_EKOSISTEMI/LRP/LRP_Demo_UI/SAP_GUI):** Geleneksel/klasik SAP arayüzlerini ("Blue Crystal" teması, ALV Grid veri tabloları, menü çubukları vb.) taklit eden simülasyonlardır. Örnek olarak [SAP_GUI/nakit akış/index.html](file:///B:/DEV/HAREZM_EKOSISTEMI/LRP/LRP_Demo_UI/SAP_GUI/nakit%20ak%C4%B1%C5%9F/index.html) incelenebilir.
2.  **[SAP_FIORI](file:///B:/DEV/HAREZM_EKOSISTEMI/LRP/LRP_Demo_UI/SAP_FIORI):** SAP UI5 / Fiori Design System standartlarına uygun modern, tile-tabanlı kurumsal ekran prototipleri.
3.  **WEB / MOBİL (Planlanan):** Modern web dashboard'ları ve mobil uygulama ekran tasarımları.

Şirketler ve entegratörler kendi kurumsal kimliklerine veya ihtiyaçlarına göre bu dizin altında kendi şablonlarını (Custom Templates) üretebilirler.

---

## 🚀 space-agent (`https://github.com/agent0ai/space-agent`) Entegrasyonu ve Konumlandırma

Bu dizindeki arayüz prototipleri, **[Space Agent](https://github.com/agent0ai/space-agent)** tarayıcı tabanlı AI çalışma alanı (workspace) ve arayüz çalışma zamanı (UI runtime) ile doğrudan entegre çalışacak şekilde konumlandırılmıştır.

```
┌─────────────────────────────────────────────────────────────┐
│                       SPACE AGENT UI                        │
│             (Tarayıcı Tabanlı AI Çalışma Alanı)             │
├──────────────────────────────┬──────────────────────────────┤
│    Kullanıcı Arayüzü / UX    │    AI Ajan İş Birliği        │
│    (Rendered HTML Widget)    │    (Dynamic Styling & Data)  │
└──────────────┬───────────────┴──────────────┬───────────────┘
               │                              │
               │ (Şablon Yükleme)             │ (Veri & JSON Bind)
               ▼                              ▼
 ┌───────────────────────────┐         ┌─────────────────────────────┐
 │       LRP_Demo_UI         │         │    LRP Çekirdek API'leri    │
 │ (Statik HTML Şablonları)  │         │ (Tenant/Object/Event Sınırı)│
 └───────────────────────────┘         └─────────────────────────────┘
```

### 1. Çalışma Zamanı ve Sandbox (UI Runtime)
`space-agent`, yapay zeka ajanlarının tarayıcı üzerinde canlı widget'lar ve arayüz alanları (Spaces) oluşturmasına ve bunları dinamik olarak yönetmesine imkan tanır. 
`LRP_Demo_UI` altındaki statik HTML şablonları, `space-agent` ekranlarında birer **etkileşimli widget/dashboard** olarak yüklenebilir ve çalıştırılabilir.

### 2. Dinamik Veri Bağlama (Mock-to-API Binding)
*   **Prototip Aşaması:** Şablonlar ilk oluşturulduğunda, `space-agent` üzerindeki AI ajanı bu statik HTML'e yerel veya anlık mock JSON verilerini enjekte ederek (Data Binding) canlı gibi çalışan bir simülasyon sunar.
*   **Canlıya Geçiş Aşaması:** Rapor backend tarafında LRP şemasına yükseltildiğinde, HTML şablonun yapısı bozulmadan; `space-agent` veri bağlama katmanı mock veri yerine gerçek LRP HTTP/GraphQL API uçlarından dönen CQRS Read View verilerini beslemeye başlar.

### 3. AI ile Ortak Arayüz Geliştirme (Co-Creation)
Kullanıcı `space-agent` üzerinde çalışırken, ekranda gördüğü bir tablonun veya kolonun değişmesini istediğinde, arka plandaki AI ajanı `LRP_Demo_UI` dizinindeki ilgili HTML dosyasını günceller. Tarayıcıdaki `space-agent` arayüzü bu değişikliği anında algılayarak güncel arayüzü kullanıcıya gösterir.

### 4. Dağıtım ve Paylaşım Senaryoları
*   **Offline/Yerel:** Arayüz şablonları tekil ve bağımsız (self-contained) yapıda olduğundan, doğrudan diskten çift tıklanarak çalıştırılabilir veya zip olarak indirilip paylaşılabilir.
*   ** space-agent Cloud/GitHub:** Geliştirilen bu demolar doğrudan `space-agent` repository'si veya GitHub Pages gibi statik sunucular üzerinden yayınlanarak paydaşlara anında canlı bir link ile sunulabilir.

---

## 🛠️ Nasıl Kullanılır?

1.  **Şablon Görüntüleme:** Herhangi bir şablonu (örneğin SAP GUI Nakit Akış Raporu) doğrudan tarayıcınızda açmak için `index.html` dosyasına çift tıklamanız yeterlidir.
2.  **space-agent Üzerinde Çalıştırma:** `space-agent` arayüzünde bir `SKILL.md` veya eklenti (plugin) tanımı üzerinden bu dizindeki dosyayı referans vererek, dinamik veri binding yetenekleriyle birlikte tarayıcı içinde zengin bir widget olarak çalıştırabilirsiniz.
