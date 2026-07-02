# ADR-0005: MIGRATION_TRACKER — Geçiş Sürecini İzleyen Katman

- **Tarih**: 2026-06-30
- **Durum**: Uygulandı
- **Kaynak**: [LRP-Mimari-v2-Protokol.md § 5](../LRP-Mimari-v2-Protokol.md)

---

## Bağlam

ADR-0004'teki Capability/Provider modeli "hangi provider aktif" sorusunu çözer. Ancak şu sorular ayrı bir katman gerektirir:
- Geçiş ne durumda?
- Yeni sistem ne kadar güvenilir?
- Tam devreye ne zaman alınmalı?
- İki provider'ın sonuçları arasında tutarsızlık var mı?

Büyük ölçekli geçişlerde (ECC → LRP gibi FI/CO/MM/SD modülleri) tek bir global tracker yetmez. Her modül/süreç bağımsız bir geçiş temposunda ilerlemelidir.

---

## Karar

`MIGRATION_TRACKER` tablosu eklenir:

```sql
MIGRATION_TRACKER (
  id                  UUID PRIMARY KEY,
  tenant_id           UUID NOT NULL,
  capability_id       UUID REFERENCES CAPABILITY,
  from_provider_id    UUID REFERENCES PROVIDER,
  to_provider_id      UUID REFERENCES PROVIDER,
  stage               TEXT NOT NULL,        -- shadow | partial | primary | full_cutover
  coverage_pct        NUMERIC(5,2),         -- yeni provider'ın yakaladığı event yüzdesi
  discrepancy_count   INTEGER DEFAULT 0,    -- iki provider arasındaki tutarsızlık sayısı
  started_at          TIMESTAMPTZ NOT NULL,
  target_cutover_at   TIMESTAMPTZ
)
```

### Stage Tanımları

| Stage | Ne oluyor | Örnek (Logo → kendi muhasebe) |
|---|---|---|
| `shadow` | Yeni provider sadece izliyor; eski provider gerçek işi yapıyor | LRP Logo'dan gelen her kaydı paralelde Ledger'a yazıyor ama hiçbir karar LRP'den çıkmıyor |
| `partial` | Yeni provider bazı düşük riskli işlemleri gerçekten yapıyor | Yeni faturalar LRP'den kesiliyor, mutabakat hâlâ Logo'dan |
| `primary` | Yeni provider ana karar mercii; eski provider yedek/doğrulama | LRP ana sistem, Logo'ya hâlâ senkron yazılıyor (geri dönüş garantisi) |
| `full_cutover` | Eski provider deprecated; yalnızca arşiv amaçlı duruyor | Logo bağlantısı kesildi |

### Discrepancy Tanımı

**Discrepancy_count** ölçülebilir olgunluk skorudur. `shadow`/`partial` aşamalarında iki provider'ın sonuçları sürekli karşılaştırılır; eşleşmezse bir discrepancy event'i oluşur.

- **Sayısal capability'lerde** (muhasebe): net rakam farkı.
- **Niteliksel capability'lerde** (mesajlaşma): `coverage_pct`, "kaç event yakalandı" değil, "N özellikten kaçı kendi sistemde var" şeklinde tanımlanır.

### Stage Geçiş Kuralları

```
shadow    → partial      : discrepancy_count belirli eşiğin altında
partial   → primary      : son 30 günde discrepancy_count = 0
primary   → full_cutover : son M ayda hiç discrepancy yok + hiç kritik hata yok
                           → sistem otomatik önerir, nihai onay DAIMA insan verir
```

### Rollback Garantisi

`primary` aşamasında bile eski provider'a senkron yazmaya devam etmek pahalı görünse de zorunludur. `full_cutover`'a yalnızca sıkı eşik koşullarıyla geçilir.

---

## Sonuçlar

**Olumlu:**
- Geçiş riski sayısal olarak izlenir; sübjektif "hazır mı" kararı önlenir.
- Büyük ölçekli geçişlerde capability bazlı granüler tempo sağlanır.
- "İnsan onayı olmadan full_cutover yok" kuralı, otomasyon güvenliğini güvence altına alır.

**Riskler / Dikkat:**
- MVP notu: Bu tabloyu gerçekten ikinci bir provider'a geçilmeye çalışılan gün ekle. Hangi alanların gerçekten gerekli olduğu gerçek geçiş deneyimiyle netleşir.
- Her `MIGRATION_TRACKER` kaydı kendi `CAPABILITY`'sine bağlıdır; çok modüllü geçişlerde bir yönetim dashboard'u gerektirir.

---

## İlgili Kararlar

- ADR-0004 (Capability/Provider/Binding) — `capability_id` ve `provider_id` bu ADR'dan gelir.
- ADR-0006 (Observation Mode) — `shadow` stage, Observation Mode altyapısını paylaşır.
