# HRP — Enterprise Uygulama Dizayn Felsefesi

SAP, Oracle ve Microsoft'un kurumsal ürünlerinin (SAP Fiori/GUI, Oracle Cloud, Dynamics 365) en büyük sorunu: **bilgi yoğunluğu ile kullanılabilirlik arasında hiç denge kuramamış olmalarıdır.** Ya çok eski/karmaşık (SAP GUI, Oracle Forms) ya da çok "consumer app gibi süslü ama enterprise işini yapamayan" (bazı yeni Fiori ekranları) yapıdadırlar. HRP, ikisinin ortasını bulmayı hedefleyerek **"power user için hızlı, yeni kullanıcı için kolay öğrenilebilir"** bir sistem sunar.

---

## 1. Temel Felsefe: "Density with Clarity" (Netlikle Birlikte Yoğunluk)

Kurumsal kullanıcı bir CRM/ERP'yi günde ortalama 8 saat kullanır. Bu kullanıcılar için yüzeysel görsellik değil **hız ve tekrarlanabilirlik** kritiktir. Ancak bu, ekranların çirkin ve düzensiz olması gerektiği anlamına gelmez.

*   **Bilgi yoğunluğu ayarlanabilir olmalı:** Kullanıcı satır yüksekliklerini ve padding oranlarını "compact (sıkışık)", "comfortable (rahat)" veya "spacious (geniş)" olarak ayarlayabilmelidir (Linear veya Notion benzeri). Klasik sistemlerde herkes tek bir şablona zorlanır.
*   **3 Saniye Kuralı:** Kullanıcı herhangi bir ekrana girdiğinde, odaklanması gereken ana işi veya yapması gereken eylemi en geç 3 saniye içinde algılayabilmelidir.
*   **Klavye Önce, Mouse Sonra:** Güçlü kullanıcılar (power users) mouse kullanmadan çalışabilmelidir. `Ctrl+K` veya `Cmd+K` komut paleti, gelişmiş Tab navigasyonu ve klavye kısayolları standart olmalı ve UI üzerinde keşfedilebilir şekilde belirtilmelidir.

---

## 2. Bilgi Mimarisi

*   **Tutarlı Üçlü Yapı:** Sol navigasyon = modüller, üst bar = context (şirket/dönem/rol seçimi), sağ panel = detay/aksiyon. Bu yerleşim tüm modüllerde tamamen aynı olmalıdır (Dynamics 365'teki modüller arası navigasyon karmaşasından kaçınılmalıdır).
*   **Derinlik Hiyerarşisi (Breadcrumb):** Derin veri ağaçlarında (Müşteri > Sipariş > Kalem > Fatura) gezinen kullanıcının kaybolmasını engellemek için Breadcrumb ve net bir "Geri Dön" butonu her zaman görünür olmalıdır.
*   **Global Arama ve Fuzzy Search:** Tek bir merkezden müşteriler, ürünler, faturalar, çalışanlar ve menü komutları aranabilmeli; modül bazlı izole aramalardan kaçınılmalıdır.

---

## 3. Data Table (Veri Tablosu): Ürünün Kalbi

Kurumsal uygulamaların %80'i tablolardan oluşur.
*   **Inline Editing (Satır İçi Düzenleme):** Hücreye çift tıklandığında düzenleme açılmalı, Enter ile kaydedilmeli, Esc ile iptal edilmelidir. Ayrı bir "edit" sayfasına gitme ihtiyacı ortadan kaldırılmalıdır.
*   **Esnek Kolon Yönetimi:** Kullanıcı kolonları gösterebilmeli, gizleyebilmeli, sıralayabilmeli, sabitleyebilmeli (freeze), genişliklerini ayarlayabilmeli ve alt toplamlar (subtotals) oluşturabilmelidir. Bu ayarlar kullanıcı profiline kalıcı kaydedilir.
*   **Toplu İşlemler (Bulk Actions):** Çoklu satır seçimi yapıldığında, tablonun üstünde içeriğe duyarlı aksiyon barı tetiklenmeli (Sil, Pasife Al, Dışa Aktar).
*   **Sanal Scroll (Virtualization):** 100.000 satırlık devasa tablolar bile donma veya kasma yaşamadan tarayıcıda akıcı şekilde kaydırılabilmelidir.
*   **Kalıcı Filtreler ve Saved Views:** Kullanıcılar oluşturdukları karmaşık filtre kombinasyonlarını kaydedip sekme olarak üstte tutabilmelidir.

---

## 4. Form Tasarımları

*   **Tek Sütun, Dikey Akış:** Çok sütunlu formların göz gezdirmeyi zorlaştıran yapısı yerine tek sütunlu dikey hizalama tercih edilmelidir.
*   **Progressive Disclosure (Kademeli Gösterim):** İleri seviye veya nadir kullanılan alanlar varsayılan olarak "Gelişmiş Ayarlar" başlığı altında gizlenmeli, ekran kalabalığı azaltılmalıdır.
*   **Sakin Inline Doğrulama (Validation):** Form hataları submit sonrası değil, kullanıcı alandan çıktığı an (blur) gösterilmelidir. Agresif kırmızı tonlar yerine stres yaratmayan turuncu veya nötr uyarı tonları tercih edilmelidir.
*   **Auto-Save:** Veri kayıplarının önüne geçmek için değişiklikler arka planda otomatik kaydedilmeli ve son kayıt zamanı küçük bir meta metin ile kullanıcıya bildirilmelidir.

---

## 5. Görsel Dil ve Renk Paleti

*   **Nötr Tonlar ve Tek Vurgu:** Koyu gri (#121214 / True Dark) ve nötr gri tonları temel alınmalı, aksiyonlar için tek bir belirgin vurgu rengi (accent color) kullanılmalıdır.
*   **Monospace Sayılar:** Finansal, sayısal ve kod verileri kesinlikle monospace (sabit genişlikli) fontlar ile gösterilerek alt alta hizalanma netliği sağlanmalıdır.
*   **Zorunlu Dark Mode:** Uzun süreli göz yorgunluğunu azaltmak için gerçek koyu gri temeller üzerine kurulu bir Gece Modu standardı olmalıdır.
*   **Tutarlı İkonografi:** Aynı eylem için her yerde birebir aynı ikon seti (örn: Lucide, Phosphor) kullanılmalıdır.

---

## 6. Performans

*   **Optimistic UI:** Kullanıcı bir işlem yaptığında arayüz sunucuyu beklemeden hemen güncellenmeli, hata durumunda işlem yumuşakça geri alınmalıdır.
*   **Skeleton Loading:** Veriler yüklenirken dairesel spinner'lar yerine iskelet (skeleton) şablonlar kullanılarak algılanan hız artırılmalıdır.
*   **SPA Akıcılığı:** Sayfalar arası geçişler anlık hissettirilmeli, tam sayfa yenilemelerinden (reload) kaçınılmalıdır.

---

## 7. Rol Bazlı Dinamik Görünümler

Aynı veri modeli, kullanıcının rolüne göre farklı karmaşıklık lensleriyle süzülmelidir. Muhasebeci en ince finansal detayları görürken, satış temsilcisi sade ve amaca yönelik bir CRM lensi ile çalışabilmelidir.

---

## 8. Karşılaştırmalı Çözüm Matrisi

| Rakip Sistem | Yaşanan Sorun (Anti-Pattern) | HRP Çözüm Yaklaşımı |
|---|---|---|
| **SAP GUI** | Modal pencere içinde modal açılması, işlem kodlarının ezberlenme zorunluluğu | Tek sayfa akışı, kısayolları ve komutları barındıran akıllı komut paleti (`Ctrl+K`). |
| **Oracle Fusion** | Aşırı yavaşlık, sürekli tam sayfa yenileme, modüller arası UX kopukluğu | SPA mimarisi, ortak ve sıkı denetlenen tek bileşen kütüphanesi. |
| **Dynamics 365** | Ribbon menü karmaşası, aşırı tıklama derinliği | Düz, hiyerarşik olmayan navigasyon ve arama odaklı erişim yapısı. |
| **Genel Enterprise** | Kullanıcı onboarding süreçlerinin olmaması veya yetersiz olması | Boş ekranlarda (empty state) "Ne yapmalıyım?" rehberleri ve bağlamsal tooltip'ler. |
