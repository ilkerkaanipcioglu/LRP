# ADR-0004: Capability/Provider/PROVIDER_BINDING — Hot-Swap Provider Pattern

- **Tarih**: 2026-06-30
- **Durum**: Kabul edildi, henüz uygulanmadı
- **Kaynak**: [LRP-Mimari-v2-Protokol.md § 4](../LRP-Mimari-v2-Protokol.md)

---

## Bağlam

LRP'de dört farklı esneklik ihtiyacı aynı anda var:
1. Bir not alma aracını yükseltmek/düşürmek (Obsidian → Notion → kendi çözümü)
2. Bir görevi agent'tan insana (veya tersi) devretmek
3. Dış sistemleri değiştirmek (Slack → kendi mesajlaşma; Logo → kendi muhasebe)
4. E-fatura/web3 gibi yeni dış sistemleri eklemek

Mevcut `AGENT_CAPABILITY` tablosu MCP araç kayıt defterini çözüyor, ancak "kim bu işi yapıyor ve nasıl değiştiririm" sorusunu çözmüyor. `PROCESS_TASK.assigned_actor_id` görev devrine kısmen cevap veriyor ama devrin nedenini ve geçmişini izlemiyor.

---

## Karar

`CAPABILITY`, `PROVIDER`, `PROVIDER_BINDING` olmak üzere üç yeni tablo eklenir. Bu tablolar "**ne** (capability)" ile "**kim/nasıl** (provider)" kavramlarını birbirinden ayırır:

```sql
-- Capability: "ne yapılması gerektiğinin" sözleşmesi
CAPABILITY (
  id              UUID PRIMARY KEY,
  tenant_id       UUID NOT NULL,
  capability_type TEXT NOT NULL,   -- note_taking | invoice_approval | messaging | accounting | ...
  interface_contract JSONB NOT NULL, -- hangi minimum fonksiyonlar zorunlu (create, read, search, export, ...)
  status          TEXT DEFAULT 'active'
)

-- Provider: "bunu gerçekte kim/ne yapıyor"
PROVIDER (
  id              UUID PRIMARY KEY,
  tenant_id       UUID NOT NULL,
  capability_id   UUID REFERENCES CAPABILITY,
  provider_type   TEXT NOT NULL,   -- internal_md | external_app | elixir_module | rust_module | php_module | agent | human
  provider_ref    JSONB NOT NULL,  -- { "path": "/notes/" } veya { "connector_id": "notion-uuid" } vb.
  version         TEXT,
  status          TEXT DEFAULT 'active'  -- active | standby | deprecated
)

-- Provider Binding: "şu an hangi provider aktif"
PROVIDER_BINDING (
  id                  UUID PRIMARY KEY,
  tenant_id           UUID NOT NULL,
  capability_id       UUID REFERENCES CAPABILITY,
  active_provider_id  UUID REFERENCES PROVIDER,
  bound_at            TIMESTAMPTZ NOT NULL,
  bound_by_actor_id   UUID REFERENCES ACTOR
)
```

### TASK Genişletmesi

`PROCESS_TASK` tablosuna şu alanlar eklenir (ayrı migration):

```sql
assignment_mode     TEXT,  -- manual | auto_agent | hybrid_approval
reassignment_reason TEXT,  -- "actor_confidence_low" | "user_preference" | ...
previous_actor_id   UUID REFERENCES ACTOR
```

### Hot-Swap'ın Üç Şartı

1. **Stabil interface_contract**: Provider değişse de capability'nin "ne yaptığı" sözleşmesi değişmez.
2. **Veri taşınabilirliği**: Her provider'ın export/import formatı OBJECT/EVENT formatına çevrilebilmelidir; aksi hâlde downgrade veri kaybına dönüşür.
3. **Binding'in kendisi versiyonlanmalı**: `PROVIDER_BINDING` değişikliği bir `VERSION` kaydı yaratmalı.

### Upgrade/Downgrade Akışı

```
1. Yeni PROVIDER oluştur (status=active)
2. EVENT(event_type=provider_migration) tetikle
3. PROVIDER_BINDING.active_provider_id → yeni provider
4. Eski provider → status=deprecated (SİLME — VERSION geçmişiyle tutarlı)
5. Downgrade: active_provider_id → eski provider'a geri çevir
```

---

## Sonuçlar

**Olumlu:**
- Çekirdek OBJECT/EVENT katmanı hiç değişmeden provider swap yapılabilir.
- `provider_type` dil-bağımsızdır: Elixir, Rust, PHP, harici uygulama veya insan.
- `reassignment_reason` + `actor_confidence` birlikte "agent'a güvenilir mi" sorusunu process mining ile cevaplanabilir kılar.

**Riskler / Dikkat:**
- `interface_contract` (JSONB) runtime'da zorlanmaz; bu bir belge sözleşmesidir. İlk uygulamada Elixir behaviour/protokolüyle eşleştirme denenmelidir.
- MVP notu: Bu tabloları gerçekten bir provider swap ihtiyacı doğduğu gün ekle. Hangi alanların gerçekten gerekli olduğu varsayımla değil, gerçek deneyimle netleşir.

---

## İlgili Kararlar

- ADR-0003 (ReBAC) — `PROVIDER_BINDING.bound_by_actor_id` yetkilendirme grafiğini kullanır.
- ADR-0005 (MIGRATION_TRACKER) — Capability geçiş sürecini izler.
