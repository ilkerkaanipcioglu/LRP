# ADR 0002: JSON Patch for Version Control Compaction

*   **Durum:** Kabul Edildi
*   **Tarih:** 2026-06-30
*   **Yazar:** Antigravity Mimar

---

## 1. Bağlam (Context)

LRP'nin Git-benzeri versiyon kontrolü vizyonu, AI ajanlarının nesneler üzerindeki her adımını izlemeyi taahhüt eder. Ancak her küçük güncellemede (örneğin sepet dökümanına ürün eklenmesi veya bir alanın değişmesi) nesnenin ve alt kalemlerinin tam bir kopyasının (`object_snapshot`) JSONB olarak kaydedilmesi, yüksek frekanslı ajan etkileşimlerinde veritabanı boyutunun (storage) kontrolsüzce büyümesine neden olacaktır. Bu durum, Git'in verimli delta/blob sıkıştırma mantığı yerine kaba bir yedekleme (backup) mantığıdır.

---

## 2. Karar (Decision)

Bu storage patlamasını ve performans kaybını önlemek için **JSON Patch (RFC 6902)** standardı ve otomatik **Compaction (Squashing)** stratejisi benimsenecektir:

1.  **Delta/Diff Depolama:** `Version` tablosunda `v1` (ilk commit) full snapshot saklarken, sonraki her commit (`v2`, `v3` vb.) sadece bir önceki sürüme göre farkları içeren bir JSON Patch listesi (örneğin: `[{"op": "replace", "path": "/status", "value": "paid"}]`) saklayacaktır.
2.  **Compaction (Squash) Eşiği:** Her **50 patch** adımında bir, sistem arka planda otomatik olarak tüm patch'leri birleştirerek güncel durumu içeren tam bir snapshot (Compaction/Squash) alacak ve delta zincirini sıfırlayacaktır.

---

## 3. Değerlendirilen Alternatifler (Alternatives)

*   **Alternatif A: Her Seferinde Full Snapshot Tutmak:** Basit bir implementasyon sunar ancak yüksek frekanslı güncellemelerde veritabanı boyutunu birkaç haftada gigabaytlarca şişireceğinden kesinlikle reddedilmiştir.
*   **Alternatif B: Git Repository Backed Storage:** Döküman geçmişlerini doğrudan fiziksel bir git reposunda (disk üzerinde) tutmak. Veritabanı işlemleriyle ACID tutarlılığını sağlamak çok zor olacağından ve transactional bütünlüğü bozacağından reddedilmiştir.

---

## 4. Sonuçlar ve Riskler (Consequences)

*   **Olumlu:** Depolama alanı maliyeti %90'ın üzerinde azalacaktır. AI ajan etkileşimleri sınırsızca loglanabilir.
*   **Negatif/Risk:** Belirli bir versiyona geri dönmek (checkout) veya o andaki nesne halini okumak, `v1`'den başlayarak patch'lerin sırasıyla uygulanmasını (compile) gerektirir. 50 patch compaction sınırı bu derleme maliyetinin milisaniyeler altında kalmasını garanti eder.
