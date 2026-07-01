# LRP — Yapılacaklar Listesi
*VISION.md + tüm mimari kararlar + konuşma geçmişi baz alınarak hazırlanmıştır.*
*Son güncelleme: 2 Temmuz 2026*

---

## Önce Bir Kural

Her sprint için tek bir kontrol sorusu:
> "Bu iş, gerçek bir kullanıcının gerçek bir sorununu bu hafta çözüyor mu?"
> Hayırsa — ertele.

---

## 🔴 HEMEN — Bu Oturum Bitmeden

### 0. Commit edilmemiş dosyaları push et
```bash
git add .
git commit -m "feat: capability, onboarding, migration_tracker schemas + ADR 0003-0006"
git push
```
**Neden şimdi:** `capability.ex`, `onboarding.ex`, `migration_tracker.ex` ve ADR'lar
hâlâ local'de. Bilgisayar kapanırsa bu konuşmada kurulan her şey kaybolur.
Bu listedeki her şeyden önce gelir.

---

## 🟠 SPRINT 1 — "Demo Edilebilir" (Bu Hafta)

Hedef: Birine gösterilecek tek bir akış uçtan uca çalışsın.

### 1. `mix lrp.status [--json]`
Sistemin anlık durumunu gösterir. Agent bu komutu çağırır, insan bu komutu çalıştırır.
```
Tenant sayısı: 2
Actor sayısı: 5 (3 human, 2 agent)
Object sayısı: 47
Event sayısı: 312 (son 24 saat: 18)
Bekleyen PROCESS_TASK: 3
```
`--json` flag: agent doğrudan `mix lrp.status --json` çağırır, parse eder.

### 2. `mix lrp.seed`
Demo verisi yükler. Gerçek bir senaryoyu simüle etmeli:
- 1 Tenant (örn. "Harezm Demo A.Ş.")
- 1 Human Actor + 1 Agent Actor
- 3-5 Object (bir fatura, bir müşteri, bir dosya)
- 5-10 Event (mail geldi, onay istendi, agent karar verdi, vb.)

### 3. `mix lrp.demo`
Seed'in üstüne, uçtan uca bir akışı canlı olarak çalıştırır:
```
[1] Tenant oluşturuluyor...          ✓
[2] Actor'lar ekleniyor...           ✓ (İlker + Hermes Agent)
[3] E-posta simüle ediliyor...       ✓ EVENT(source: email)
[4] Document Object oluşturuluyor... ✓ OBJECT(type: Document)
[5] Agent sınıflandırıyor...         ✓ confidence: 0.87
[6] PROCESS_TASK oluşturuldu...      ✓ "Fatura onayı bekliyor"
[7] mix lrp.status --json            ✓

Demo tamamlandı. Sistem çalışıyor.
```
Bu komut, yatırımcıya/müşteriye gösterilen şey.
5 dakikada LRP'nin ne yaptığını anlatır.

### 4. `setup.sh` / `setup.ps1`
Tek komutla kur:
```bash
curl -s https://raw.githubusercontent.com/ilkerkaanipcioglu/LRP/main/setup.sh | bash
```
İçinde: Elixir/Erlang kontrolü, `mix deps.get`, `mix ecto.setup`, `mix lrp.seed`.

### 5. `mix test` — hâlâ 8 yeşil mi?
Her sprint başında ve sonunda çalıştır. Yeşil değilse başka hiçbir şeye geçme.

---

## 🟡 SPRINT 2 — "İlk Gerçek Kaynak" (Haftaya)

Hedef: Gerçek bir GitHub repo'yu okuyup anlamlı bir çıktı üret.

### 6. CodeParser Agent — Elixir için
Bir GitHub repo'daki Elixir kodunu okur, Object Graph'e çevirir:

```elixir
# Girdi: lib/lrp/object.ex
# Çıktı:
OBJECT(type: "Module", name: "LRP.Object", metadata: %{
  functions: ["create/2", "get/1", "list/2"],
  dependencies: ["LRP.Repo", "LRP.Tenant"],
  summary: "LRP nesne katmanı. CRUD operasyonları yönetir."
})
RELATIONSHIP(from: "LRP.Object", to: "LRP.Repo", type: "depends_on")
```

**Önemli mimari karar:** Tree-sitter ile yaz.
Elixir parser bugün, Python parser yarın aynı altyapıyla gelir.
Elixir-specific yazarsan ileride her dil sıfırdan.

### 7. `mix lrp.analyze --source <path|url>`
```bash
mix lrp.analyze --source https://github.com/user/legacy-app
mix lrp.analyze --source /Users/ilker/projects/old-system
```
Çıktı:
```
Analiz ediliyor: legacy-app
  → 47 modül bulundu
  → 312 fonksiyon
  → 8 dış bağımlılık
  → LRP uyumluluk skoru: %34

Düşük uyumluluk nedenleri:
  ✗ Event emit edilmiyor (23 modül)
  ✗ idempotency_key yok (47/47 fonksiyon)
  ✗ Actor bazlı işlem yok

PROCESS_TASK'lar oluşturuldu: 12
IT onayı bekliyor: mix lrp.tasks
```

### 8. `mix lrp.tasks [--json]`
Bekleyen PROCESS_TASK listesi + onay arayüzü:
```
#  | Görev                              | Confidence | Risk  | Durum
1  | Rewrite: UserController            | 0.91       | LOW   | Onay bekliyor
2  | Add: idempotency_key (47 fn)       | 0.98       | LOW   | Onay bekliyor
3  | Add: EVENT emit (OrderService)     | 0.76       | MEDIUM| Onay bekliyor

[a] Onayla  [r] Reddet  [e] Düzenle  [s] Sonraki
```

---

## 🟢 SPRINT 3 — "İlk Müşteri Konuşması" (2 Hafta)

Hedef: Bir SAP müşterisine "AS-IS analizi" olarak satılabilir çıktı üret.

### 9. ObservationMode
```bash
mix lrp.observe --system sap_ecc --duration 30d --purpose documentation_only
```
- Mevcut sistemi izler, EVENT toplar
- Süreç haritası çıkarır (process mining)
- Markdown/PDF rapor üretir
- Müşteri LRP'ye geçmek zorunda değil

**Neden bu kadar önemli:** Sıfır riskli, hemen satılabilir.
SAP'tan LRP'ye geçiş büyük bir taahhüt. "Önce süreçlerini belgeleyelim" çok daha kolay bir ilk adım.
Buradan müşteri güveni kazanılır, sonra büyük migration konuşması başlar.

### 10. `mix lrp.maturity [--tenant ID]`
```
Tenant: Harezm Demo A.Ş.
Gözlem süresi: 18 gün
Coverage: %67 (340/510 event yakalandı)
Discrepancy: 3 (son 7 günde)
Agent güven ortalaması: 0.84

Durum: PARTIAL moda geçmeye henüz hazır değil
Neden: Discrepancy > 0, coverage < %80
Öneri: 12 gün daha gözlem, sonra tekrar değerlendir
```
"Ne zaman devreye alacağım" sorusunu insan değil sistem cevaplar.

### 11. RewriteTask Generator
`mix lrp.analyze` çıktısını alır, gerçekten kod yazar:
- Onaylanan PROCESS_TASK → Elixir kodu üretir
- `mix test` çalıştırır
- Yeşilse PR açar
- Kırmızıysa IT'ye bildirir

**Karar protokolü (AGENTS.md'ye ekle):**
```
Otomatik PR açılabilir:
  confidence > 0.90 AND risk_level = LOW AND test_coverage > %90

İnsan onayı zorunlu:
  confidence < 0.90
  LEDGER'a yazma
  FISCAL_PERIOD = closed dönem
  discrepancy_count > 5 (son 24 saat)
```

---

## 🔵 SPRINT 4 — "Para Kazanan Parça" (1 Ay)

### 12. Minimum Viable Ledger
Sadece bunlar — fazlası değil:
```sql
LEDGER(id, tenant_id, scheme[VUK|IFRS], is_leading, status)
JOURNAL(id, tenant_id, ledger_id, doc_date, posting_date, source_event_id)
JOURNAL_LINE(id, journal_id, account_id, debit, credit, currency, is_reversed)
FISCAL_PERIOD(id, tenant_id, ledger_id, period_start, period_end, status[open|closed])
```

Tek hedef: bir EVENT (fatura onaylandı) → otomatik JOURNAL oluşsun.
FISCAL_PERIOD kapalıysa reddetsin. Açıksa kabul etsin.

`ACCOUNT_MAPPING`, `POSTING_RULE`, multi-ledger paralel posting → Sprint 5+

### 13. Direction Listener (Email → PROCESS_TASK)
```
E-posta: "Discord entegrasyonu ekleyelim"
  → EVENT(source: email, type: feature_request)
  → Agent yorumlar + confidence atar
  → PROCESS_TASK oluşturur
  → IT'ye ApprovalRequest gider
  → Onay → geliştirme başlar
```

### 14. İlk Gerçek Connector
Slack veya email outbound — hangisi gerçek bir müşteri ihtiyacı ise o.
Varsayımla seçme.

---

## ⚪ SPRINT 5+ — "Platform Olmak" (2-3 Ay)

### 15. Surface Builder v1
Kullanıcı kendi ekranını tasarlar, core'a dokunamaz:
```
"Bu haftaki onay bekleyen task'ları listele, kim onayladı göster"
  → Agent Core API'den çeker (salt okunur)
  → LiveView component oluşturur
  → Kullanıcıya preview
  → Kaydet → tenant'a özel ekran
```
space-agent mantığı: agent destekli no-code UI.

### 16. Multi-language Parser
Tree-sitter zaten v0.2'de kuruluysa bu sadece yeni grammar ekleme:
- Python → Sprint 5
- JavaScript/TypeScript → Sprint 6
- Ruby, Go → talebe göre

### 17. Continuous Loop
Sistem değişti → LRP yeniden analiz eder → yeni PROCESS_TASK önerir.
Bu, "LRP kendi kodunu da izler" hedefinin başlangıcı.

### 18. ACCOUNT_MAPPING + POSTING_RULE
Multi-GAAP paralel posting (VUK + IFRS aynı anda).
Minimum Ledger çalışıp gerçek veri gördükten sonra.

---

## 📋 Özet Tablo

| Sprint | Hedef | Kritik Çıktı |
|---|---|---|
| Hemen | Commit push | Kayıp riski yok |
| Sprint 1 | Demo edilebilir | `mix lrp.demo` çalışıyor |
| Sprint 2 | İlk kaynak analizi | `mix lrp.analyze` + CodeParser |
| Sprint 3 | Satılabilir ürün | ObservationMode raporu |
| Sprint 4 | Para kazanan parça | Minimum Ledger + Direction Listener |
| Sprint 5+ | Platform | Surface Builder + Multi-language |

---

## ❌ Şimdi Yapılmayacaklar

| Ne | Neden Değil |
|---|---|
| Rust/NIF | Ölçüm yoksa Rust yok (VISION.md'de de bu var) |
| Web3 entegrasyonu | Gerçek müşteri talebi gelince |
| ACCOUNT_MAPPING, multi-ledger | Minimum Ledger çalışmadan |
| SPK konsolidasyon | Sprint 6+ |
| Full Surface Builder | Önce Core sağlam olmalı |
| "En iyi çekirdek" hedefi | Bu liste zaten ona götürür, hedef olarak kullanılmaz |

---

## 🎯 v1.0 Çıkış Kriterleri

- `mix lrp.demo` 5 dakikada çalışıyor ve anlaşılıyor
- En az 1 gerçek müşteri, 30 gün production event akışı
- Günlük 1.000+ event, discrepancy = 0
- Minimum Ledger: VUK kaydı kapanıyor, FISCAL_PERIOD kilidi çalışıyor
- ObservationMode: en az 1 müşteriye "as-is raporu" teslim edildi
- 0 P0 bug, 0 commit edilmemiş şema değişikliği

---

*Bu liste VISION.md felsefesinin uygulama planıdır.
Her sprint sonu: mix test yeşil mi? Demo çalışıyor mu? Müşteriye gösterilebilir mi?
Üçü de evetse bir sonraki sprint'e geç.*
