# SAP GUI Design Philosophy & Component Standards

Bu doküman, **LRP_Demo_UI/SAP_GUI** altındaki tüm geleneksel SAP ekran simülasyonlarının uyması gereken görsel standartları ve bileşen kurallarını tanımlar. Amaç, retro kurumsal SAP GUI ("Blue Crystal" light) görünümünün tüm ekranlarda tutarlı kalmasını sağlamaktır.

Tüm SAP GUI demoları ortak stil dosyası olan **[sapgui.css](file:///B:/DEV/HAREZM_EKOSISTEMI/LRP/LRP_Demo_UI/SAP_GUI/sapgui.css)** dosyasını kullanmalıdır.

---

## 1. Grid & Sayfa Yerleşimi (Layout)

Her ekran bir ana SAP Window container'ından oluşur ve şu dikey hiyerarşiyi takip eder:
1.  **Titlebar (`.sap-titlebar`):** Uygulama başlığı ve pencere kontrol butonları (`_`, `[]`, `X`).
2.  **Menubar (`.sap-menubar`):** Klasik SAP üst menüleri (Belge, Düzenle, Git, Sistem, Yardım).
3.  **Standard Toolbar (`.sap-toolbar`):** Komut satırı giriş kutusu, kaydet butonu ve navigasyon yön okları.
4.  **Titlestrip (`.sap-titlestrip`):** İşlemin sistem adı ve işlem kodu (örn: "Yevmiye Fişi Girişi - FB50").
5.  **App Toolbar (`.sap-apptoolbar`):** O uygulamaya özel eylem butonları (Simüle et, Satır Ekle, Satır Sil vb.).
6.  **Content (`.sap-content`):** Form elemanları ve ALV Grid veri tabloları.
7.  **Statusbar (`.sap-statusbar`):** Ekranın en altında yer alan, sistem mesajlarını (Error, Success, Info), oturum bilgilerini ve sistem adını gösteren çubuk.

---

## 2. Arama ve Komut Satırı (Command Field)

*   **Komut Satırı (`.sap-cmd`):** Standard Toolbar'ın en solunda yer alır. `/n` ile başlayan işlem kodlarını simüle etmek için kullanılır (örn: `/nFB50` yevmiye fişine, `/nFB03` belge görüntülemeye yönlendirir).
*   **Arama Girişleri:** Arama filtreleri Selection Screen çerçevesi (`.ss-frame`) içinde dikey form alanları şeklinde sunulur. Çoklu arama ve aralık girmek için `.ss-selopt` ve çoklu seçim butonu `.ss-mc` (sarımsı arama butonu) kullanılır.

---

## 3. Buton Standartları

*   **Araç Çubuğu Butonları (`.sap-btn`):**
    *   Yalnızca ikon içerirler (veya `.with-text` sınıfıyla birlikte metin).
    *   Hover durumunda açık mavi kenarlık (`#9bb8d6`) ve çok hafif arka plan kazanırlar.
    *   Pasif durumlar için `disabled` niteliği taşırlar.
*   **Push Butonlar (`.btn`):**
    *   Form içindeki eylemler veya dialog pencerelerinin altındaki standart eylemler için kullanılır.
    *   Hafif gri-beyaz degrade arka plan ve ince kenarlığa sahiptirler.
    *   Ana aksiyon butonu `.btn.primary` sınıfı ile belirginleştirilir.

---

## 4. Veri Tablosu (ALV Grid)

SAP GUI'nin kalbi olan **ALV (ABAP List Viewer) Grid** yapısı `.alv-table` sınıfı ile kurulur:
*   **Başlıklar (`.alv-th`):** Sticky yapıda, gri-mavi degrade arka planlıdır. Sıralama yapılabileceğini belirtmek için tıklanabilir olmalıdır.
*   **Satırlar (`.alv-tr`):** Zebra desenli (`.alv-tr:nth-child(even) .alv-td`) arka plan standardına sahiptir. Hover durumunda açık mavi renkle vurgulanır.
*   **Seçim:** Seçili satırlar `.sel` sınıfını alır ve sarımsı-turuncu (`--alv-sel`) renge boyanır.
*   **Tutarlar (`.alv-td.amount`):** Mutlaka sağa hizalanmalı ve alt alta düzgün görünmesi için monospace (`font-variant-numeric: tabular-nums`) sayılarla gösterilmelidir. Negatif tutarlar `.neg` sınıfıyla kırmızı renkte yazılır.

---

## 5. Durum Bildirimleri (Statusbar Messages)

Kullanıcı bir işlem yaptığında ekranın sol altındaki statusbar üzerinde şu standart mesaj tipleri gösterilmelidir:
*   **Success (S):** `S: ZFI002 Belge 100000001 başarıyla oluşturuldu` (Yeşil zeminli onay mesajı).
*   **Error (E):** `E: Borç ve alacak bakiyesi eşit olmalıdır!` (Kırmızı zeminli hata uyarısı).
*   **Info (I):** `I: Zaten FB50 işlemindesiniz` (Nötr bilgi mesajı).
