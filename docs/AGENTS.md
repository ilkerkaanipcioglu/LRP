# DOX framework — docs/

- Parent: [LRP root AGENTS.md](../AGENTS.md)
- Scope: All documentation files under `docs/`

## Local Contract

Bu dizin LRP için **Architecture Decision Records (ADR)** ve diğer kalıcı dokümantasyonu içerir. ADR'lar kabul edildikten sonra değişmezdir — değişen bir karar için yeni bir ADR oluşturulur; orijinal dosya hiç düzenlenmez.

Birincil mimari spesifikasyon: [`LRP-Mimari-v2-Protokol.md`](../LRP-Mimari-v2-Protokol.md)

---

## ADR İndeksi

| Dosya | Karar | Durum |
|---|---|---|
| [`adr/0001-cqrs-read-views.md`](adr/0001-cqrs-read-views.md) | CQRS Okuma Görünümleri (maks. 5 sn. gecikme) | Kabul edildi, henüz uygulanmadı |
| [`adr/0002-json-patch-versioning.md`](adr/0002-json-patch-versioning.md) | JSON Patch (RFC 6902) delta'ları + 50-patch compaction | Kabul edildi, henüz uygulanmadı |
| [`adr/0003-rebac-authorization.md`](adr/0003-rebac-authorization.md) | OpenFGA ile ReBAC Yetkilendirmesi | Kabul edildi, henüz uygulanmadı |
| [`adr/0004-capability-provider-binding.md`](adr/0004-capability-provider-binding.md) | Capability/Provider/PROVIDER_BINDING — hot-swap provider pattern | Uygulandı |
| [`adr/0005-migration-tracker.md`](adr/0005-migration-tracker.md) | MIGRATION_TRACKER — shadow/partial/primary/full_cutover | Uygulandı |
| [`adr/0006-observation-mode.md`](adr/0006-observation-mode.md) | OBSERVATION_MODE + MATURITY_SCORE — three onboarding scenarios | Uygulandı |
| [`adr/0007-connector-contract.md`](adr/0007-connector-contract.md) | Standart Connector/Adapter kontratı + EVENT_SUBSCRIPTION outbound | Uygulandı |
| [`adr/0008-modular-data-integration-topology.md`](adr/0008-modular-data-integration-topology.md) | Modüler Veri Entegrasyon Topolojisi & Yetenek Genişletilebilirliği | Uygulandı |
| [`adr/0009-hybrid-frontend-architecture.md`](adr/0009-hybrid-frontend-architecture.md) | Hibrit Ön Yüz Mimarisi (Phoenix LiveView & Rust/WASM/Perspective) | Uygulandı |

---

## ADR Düzenleme Kuralları

1. **Kabul edilmiş ADR'ı asla düzenleme.** Karar değişirse, eskisini açıkça geçersiz kılan yeni bir ADR yaz ve eski ADR'ın durumunu "ADR-XXXX tarafından geçersiz kılındı" olarak güncelle.
2. **Yeni ADR isimlendirmesi**: `NNNN-kisa-slug.md` formatı; NNNN sıfırla doldurulmuş 4 haneli sıra numarası.
3. **ADR formatı**: Başlık, Tarih, Durum, Bağlam, Karar, Sonuçlar bölümlerini içermeli.
4. **ADR Kabul → Uygulandı geçişi**: ADR dosyasındaki durum alanını güncelle ve bu tablodaki durumu da güncelle.
5. **ADR ekledikten veya güncelledikten sonra**: Kök `README.md`'deki ADR tablosunu da güncelle.

## Diğer Dokümanlar

ADR olmayan tasarım dokümanları doğrudan `docs/` klasörüne açıklayıcı bir isimle konur. Yeni belge oluşturulduğunda bu AGENTS.md'ye de eklenir.

- [`docs/ROADMAP.md`](docs/ROADMAP.md) — LRP Yol Haritası ve Sprint Planları
- [`docs/POSITIONING.md`](docs/POSITIONING.md) — Pazar Konumlandırması ve Rekabet Analizi (SAP, Odoo, Oracle, Microsoft Dynamics Çelişkileri)
- [`docs/PLUGGABLE-APPLICATIONS.md`](docs/PLUGGABLE-APPLICATIONS.md) — Değişebilir Uygulamalar Prensibi (Pluggable Applications Principle)
- [`docs/FRONTEND-STRATEGY.md`](docs/FRONTEND-STRATEGY.md) — Ön Yüz Stratejisi (Frontend Strategy - LiveView & Rust/WASM)

- 🔴 **Software Engineering Principles**: Geliştirmeye başlamadan önce mutlaka [ENTERPRISE-ENGINEERING-PRINCIPLES.md](file:///B:/DEV/ENTERPRISE-ENGINEERING-PRINCIPLES.md) dosyasını okuyun, projenin tier seviyesini belirleyin ve kurallara uyun. Eğer bu kurallar dışında bir uygulama yapılacaksa bu durum `AGENTS.md` dosyasında belirtilmelidir; gerekirse `ENTERPRISE-ENGINEERING-PRINCIPLES.md` dosyası proje klasörüne kopyalanıp özelleştirilmiş bir versiyonu oluşturulabilir. Değişiklik küçükse sadece `AGENTS.md` dosyasında belirtilmesi yeterlidir.
