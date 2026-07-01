# ADR 0003: ReBAC (Relation-based Access Control) with OpenFGA

*   **Durum:** Kabul Edildi
*   **Tarih:** 2026-06-30
*   **Yazar:** Antigravity Mimar

---

## 1. Bağlam (Context)

LRP'nin `POLICY(actor_id, resource_type, action, effect)` tablosundaki statik ve jenerik yetkilendirme modeli, nesne grafının (`RELATIONSHIP`) sunduğu zengin bağlamsal ilişkileri korumak için yetersiz kalmaktadır. Gerçek kurumsal senaryolarda "Bir kullanıcı sadece kendi departmanındaki (`OBJECT.Folder`) nesnelere ait faturaları (`OBJECT.Document`) görebilsin" veya "Bir yönetici sadece kendi astlarının izin taleplerini onaylayabilsin" gibi dinamik ve ilişki-bazlı kuralların tanımlanması gerekmektedir. Sıfırdan bir yetki grafı sorgulayıcısı (custom graph traversal) yazmak ise yüksek performans ve bakım yükü (technical debt) getirecektir.

---

## 2. Karar (Decision)

LRP bünyesinde **Relation-based Access Control (ReBAC)** yetki modeli benimsenecek ve bu modeli koşturmak için sıfırdan kod yazmak yerine Google Zanzibar modelini uygulayan **OpenFGA** (battle-tested, açık kaynaklı CNFC projesi) standart olarak entegre edilecektir:

1.  **Relation-based Authorization:** Yetki kontrolleri nesneler arasındaki bağların (`RELATIONSHIP`) sorgulanmasıyla çözülecektir.
2.  **Zanzibar Entegrasyonu:** LRP, yetki şemasını (Authorization Model) OpenFGA DSL formatında deklare edecek ve kontrol sorgularını OpenFGA API/SDK katmanına delege edecektir (Buy over Build kararı).
3.  **Local Relationship as Source of Truth (Tek Kaynak):** SQLite/Postgres üzerindeki yerel `relationships` tablosu **tek gerçeklik kaynağı (single source of truth)** olarak kabul edilir. OpenFGA ise bu tablodan beslenen bir **asenkron türev önbellek (replica cache)** olarak konumlandırılır. 
    *   **Asenkron Yazma (Async Sync-on-Write) ve Idempotency:** `LRP.relate/5` write-path'i yavaşlatmamak adına OpenFGA'ya doğrudan senkron yazmaz. Bunun yerine, bir **Asenkron Event Listener** `relationships` tablosundaki değişiklikleri dinler ve OpenFGA API'sine yazar. Hata veya kesinti durumlarında işlemleri **Dead Letter Queue (DLQ)** katmanına alarak best-effort tutarlılık sağlar.
    *   **OpenFGA Idempotency Güvencesi:** OpenFGA'in kendi Write API'si tuple yazma (`write`) ve silme (`delete`) işlemlerinde **native olarak idempotenttir**. Zaten var olan bir tuple tekrar yazıldığında hata fırlatmaz, başarılı döner. Bu sayede DLQ yeniden denemelerinde (retry) OpenFGA tarafında mükerrer ilişki veya çift tuple oluşma riski yoktur. 

---

## 3. Değerlendirilen Alternatifler (Alternatives)

*   **Alternatif A: Custom Elixir Graph Traversal (Sıfırdan Yazmak):** Libgraph vb. kütüphanelerle grafı bellek üzerinde taramak. Yetkiler büyüdükçe (milyonlarca nesne ve ilişki) performans optimizasyonu ve cache yönetimi aşırı karmaşıklaşacağı için reddedilmiştir.
*   **Alternatif B: Klasik Rol Bazlı Yetki (RBAC):** Statik roller (Admin, Manager, User) tanımlamak. Kurumsal esneklik ve dinamik ilişki yetkilendirmelerini (örn: "dosya sahibi", "departman üyesi") çözemediği için reddedilmiştir.

---

## 4. Sonuçlar ve Riskler (Consequences)

*   **Olumlu:** Karmaşık ilişkisel yetkiler milisaniyeler altında ve merkezi olarak yönetilebilir hale gelecektir. Kendi yazacağımız binlerce satır optimize edilmemiş koddan tasarruf edilmiştir. Write-path OpenFGA ağ gecikmelerinden veya kesintilerinden etkilenmez.
*   **Negatif/Risk:** LRP altyapısına OpenFGA (veya uyumlu bir sidecar/microservice) bağımlılığı eklenmiştir. Asenkron senkronizasyon nedeniyle yetkilerin güncellenmesinde çok kısa süreli milisaniyelik eventual consistency gecikmeleri olabilir. MVP aşamasında bu durum basit bir Elixir Mock ReBAC modülü ile simüle edilecek, production'da gerçek OpenFGA server'a bağlanacaktır.

