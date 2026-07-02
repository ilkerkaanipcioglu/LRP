# ADR-0006: OBSERVATION_MODE + MATURITY_SCORE — Üç Onboarding Senaryosu

- **Tarih**: 2026-06-30
- **Durum**: Uygulandı
- **Kaynak**: [LRP-Mimari-v2-Protokol.md § 6–7](../LRP-Mimari-v2-Protokol.md)

---

## Bağlam

LRP'nin "mevcut sisteme yerleşme" iddiası tek bir senaryo değildir; üç kategorik olarak farklı kullanım vardır. Kullanıcı "sıfırdan mı, mevcut bir sistemi mi?" sorusuna göre farklı yollara ayrılır. Mevcut implementasyon bu ayrımı yönetmiyor ve "LRP ne zaman devreye alınmaya hazır?" sorusuna somut bir cevap vermiyor.

---

## Karar

### OBSERVATION_MODE Tablosu

```sql
OBSERVATION_MODE (
  id              UUID PRIMARY KEY,
  tenant_id       UUID NOT NULL,
  scope           TEXT NOT NULL,  -- full_system | specific_process
  target_system   TEXT NOT NULL,  -- izlenen sistemin adı/referansı
  purpose         TEXT NOT NULL,  -- documentation_only | pre_migration | continuous_shadow
  started_at      TIMESTAMPTZ NOT NULL,
  ended_at        TIMESTAMPTZ
)
```

### Üç Senaryo

#### Senaryo A — Sadece Dokümante Et (`purpose=documentation_only`)
- Geçiş niyeti olmadan salt gözlem: *"sisteme dokunmuyoruz, sadece izliyoruz."*
- Agent hiçbir öneri/geçiş tetiklemez; yalnızca **süreç haritası** üretir.
- En kolay satılabilir, sıfır riskli LRP kullanım biçimidir — müşteriye LRP'nin kendisini anlatmaya gerek kalmaz.

#### Senaryo B — ECC → HANA (`purpose=pre_migration`)
- LRP geçiş hedefi değildir (ikisi de SAP); LRP **geçişin hafızasıdır**.
- ECC akışı gölge modda izlenip gerçek süreç haritası çıkarılır.
- HANA sonrası aynı izleme tekrarlanır; iki snapshot karşılaştırılır: *"bu adım kayboldu mu / değişti mi?"*
- Mevcut SAP danışmanlık müşterilerine LRP'yi hiç göstermeden satılabilen ayrı bir hizmet hattıdır.

#### Senaryo C — ECC → LRP (`purpose=continuous_shadow`)
- ADR-0005'teki `MIGRATION_TRACKER` senaryosudur, büyük ölçekte ve modül bazlı.

### Ortak Motor, Farklı Çıkış

| Senaryo | Çıkış Modu |
|---|---|
| A — Dokümantasyon | Rapor üret, dur |
| B — ECC → HANA | İki snapshot'ı karşılaştır, fark raporu üret |
| C — ECC → LRP | Gerçek capability swap'a kadar götür |

### MATURITY_SCORE

LRP'nin devreye alınmaya hazır olup olmadığı sübjektif bir insan kararına bırakılmamalıdır. Somut eşikler:

- **Coverage bazlı**: "Olayların %X'i artık EVENT olarak yakalanıyor"
- **Confidence bazlı**: "Agent'ın süreç çıkarımı son N olayda %X doğrulukla onay aldı"
- **Zaman bazlı**: "30 gün kesintisiz paralel veri toplandı"

Kullanıcıya dashboard'da somut bir ilerleme çubuğu gösterilir:
*"LRP şu an sürecinizin %72'sini görüyor; %90'a ulaşınca devreye almayı önereceğiz."*

### Gölge Fazda Agent Davranış Kuralı

- Gölge fazda agent **öneri üretmez**, yalnızca gözlemler.
- Öneri üretilecekse açıkça **"preview/sandbox"** etiketiyle işaretlenmeli.
- İlk sürümde mail sınıflandırması insan onaylı olmalı: Agent "bu maili Fatura Onayı olarak sınıflandırdım, doğru mu?" diye sorar — bu hem eğitim verisi üretir hem de erken güven kırmasını önler.

---

## Sonuçlar

**Olumlu:**
- Ticari kademe sunar: önce risksiz dokümantasyonla güven → sonra geçiş doğrulama → en sona tam migrasyon.
- `MATURITY_SCORE` ile "hazır mı" kararı ölçülebilir hâle gelir.
- Senaryo A, SAP danışmanlık müşterilerine LRP mimarisini anlatmadan satılabilir bir ürün olarak çalışır.

**Riskler / Dikkat:**
- `MATURITY_SCORE` hesaplama formülü ilk gerçek müşteri onboardinginde kalibre edilmelidir — varsayım değil ölçüm.
- Gölge fazda agent'ın "sadece gözlemle" kuralının teknik zorunluluğa dönüştürülmesi (feature flag veya mode check) gereklidir.

---

## İlgili Kararlar

- ADR-0005 (MIGRATION_TRACKER) — Senaryo C'nin altyapısını sağlar.
- ADR-0007 (Connector Contract) — Gölge mod için dış sistem bağlantısı gerektirir.
