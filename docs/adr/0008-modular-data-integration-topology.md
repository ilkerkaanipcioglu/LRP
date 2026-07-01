# ADR 0008: Modular Data Integration Topology & Capability Extensibility

## Durum (Context)
LRP (Lightweight Resource Planning) sisteminin çoklu etki alanı (CRM, ERP, E-Ticaret, Mesajlaşma vb.) üzerinde çalışırken iki kritik mimari gereksinimi karşılaması gerekmektedir:
1. **Veri Entegrasyon Esnekliği**: CRM, ERP ve E-Ticaret gibi modüllerin tek bir ortak veritabanında (Single Table) çalışabilmesi, fakat aynı zamanda ayrı bağımsız sistemler olarak konumlandırıldıklarında aralarında senkronize ve kolay entegre (Federated Mode) olabilmesi bir tercih/konfigürasyon olmalıdır.
2. **Modüler Genişletilebilirlik**: E-Ticaret veya Mesajlaşma gibi servisler LRP native modülleri olarak takılabilmeli, ancak istendiğinde kullanıcı kendi özel uygulamasını yazabilmeli ya da 3. parti bir sistemi (örn: Shopify, Twilio) sıcak geçişle (hot-swap) entegre edebilmelidir.

## Kararlar

```mermaid
graph TD
    subgraph LRP Core
        Graph[(Unified Object Graph DB)]
        CapReg[Capability Registry]
    end

    subgraph Modül Seçenekleri (Hot-Swappable Providers)
        subgraph E-Ticaret (Ecommerce Capability)
            N_Ecom[LRP Native Ecom]
            C_Ecom[Custom Ecom App]
            T_Ecom[3rd Party Shopify]
        end
        subgraph Mesajlaşma (Messaging Capability)
            N_Msg[LRP Native Chat]
            C_Msg[Custom Telegram Bot]
            T_Msg[3rd Party WhatsApp]
        end
    end

    CapReg -->|Interface Binding| N_Ecom
    CapReg -->|Interface Binding| T_Ecom
    CapReg -->|Interface Binding| N_Msg
    CapReg -->|Interface Binding| T_Msg

    N_Ecom -->|Direct DB Write| Graph
    T_Ecom -->|Connector Sync & Webhook| Graph
```

### Karar 1: Çift Modlu Veri Topolojisi (Unified vs. Federated)
Sistem yöneticisi, LRP entegrasyonu için aşağıdaki iki topolojiden birini konfigüre edebilir:

* **Unified Mode (Ortak Veritabanı)**:
  * CRM, ERP, E-Ticaret ve Mesajlaşma verileri tek bir veritabanı şemasında (`objects` ve `relationships`) barındırılır.
  * Veri tekilleştirilmiştir (Single Source of Truth). CRM'deki `Person` nesnesi, e-ticaretteki `customer` rolünü üstlenir ve doğrudan ERP siparişleri ve faturalarıyla ilişkilendirilir.
  * Senkronizasyon yükü ve gecikmesi sıfırdır.
* **Federated/Synchronized Mode (Dağınık Veritabanları)**:
  * Sistemler ayrı sunucularda ve farklı veritabanlarında yaşar.
  * LRP, bu harici sistemlerle [ADR 0007 (Connector Contract)](file:///B:/DEV/HAREZM_EKOSISTEMI/LRP/docs/adr/0007-connector-contract.md) ve [ADR 0005 (Migration Tracker)](file:///B:/DEV/HAREZM_EKOSISTEMI/LRP/docs/adr/0005-migration-tracker.md) protokolleri üzerinden haberleşir.
  * Harici sistemde oluşan bir müşteri (örn: harici e-ticaret üyesi) bir `source_connected` veya `entity_created` olayıyla LRP olay akışına (Event Stream) düşer. LRP otonom olarak bu veriyi kendi grafında günceller ve değişiklikleri webhook/API çağrılarıyla diğer bağlı sistemlere iterek (push) senkronizasyon sağlar.

### Karar 2: Yetenek Tabanlı Modülerlik (First-Party vs. Third-Party Swap)
LRP bünyesindeki tüm modüller (E-Ticaret, Mesajlaşma vb.) birer **`Capability` (Yetenek Sözleşmesi)** olarak soyutlanır. Her yetenek için birden fazla **`Provider` (Sağlayıcı)** tanımlanabilir.

Kullanıcı şu üç entegrasyon yönteminden birini seçebilir:
1. **LRP Native (First-Party)**: LRP'nin yerleşik sunduğu modüldür. Doğrudan `objects` ve `relationships` tablolarını kullanarak çalışır. Kurulum gerektirmez.
2. **Kullanıcı Yapımı (Custom)**: Kullanıcı, LRP API'lerini çağırarak kendi özel iş mantığını (Business Logic) yazar. LRP nesnelerini kendi kurallarına göre manipüle eder.
3. **Üçüncü Parti (Third-Party Integration)**: Hazır servisler (Shopify, Twilio, WhatsApp, Salesforce) entegre edilir. LRP'ye o servise ait `ProviderBinding` eklenir. LRP graf sorguları veya ajan komutları, hangi sağlayıcının aktif olduğuna bakmaksızın ortak `Capability` API arayüzlerini çağırır.

## Sonuçlar
* **Esneklik**: Müşteriler küçük ölçekte tek bir ortak veritabanıyla (Unified Mode) başlayıp, ölçek büyüdükçe veya legacy sistemler entegre edildikçe federated senkronizasyon moduna geçiş yapabilirler.
* **Plug-and-Play (Tak-Çalıştır)**: E-Ticaret veya Mesajlaşma altyapıları, LRP çekirdek koduna dokunmadan hot-swap (sıcak geçiş) ile değiştirilebilir. Ajanlar aynı yetenek arayüzünü kullanmaya devam eder.
