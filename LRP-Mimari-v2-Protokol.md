# LRP — Protokol Olarak Çekirdek
## v2: Dil-Bağımsız, Agent-Native, Sadeleştirilmiş Mimari

---

## 0. Önce En Önemli Karar: LRP Bir Dil Değil, Bir Protokoldür

Önceki taslaklarda LRP, Elixir/BEAM üzerine kurulu bir runtime gibi konumlandırılmıştı. Bu doküman bunu düzeltir:

> **LRP, belirli bir programlama diline bağlı bir çalışma zamanı değil; üç tabloluk bir veri sözleşmesi (TENANT, OBJECT/ACTOR, EVENT) ve bu sözleşmeyi sağlayan herkesin uyması gereken bir entegrasyon kontratıdır.**

Bunun pratik sonucu:

- Siz Elixir ile bir **referans implementasyon** kurarsınız (Bölüm 3'teki gibi, kanıtlanmış ve hızlı).
- Bir geliştirici aynı LRP mantığını **Rust, PHP, Python, Go, Java** ile de uygulayabilir — yeter ki OBJECT/EVENT/CONNECTOR kontratına uysun. LRP'nin kendisi bir kütüphane değil, bir **şema + protokol spesifikasyonudur** (tıpkı HTTP'nin C, Go veya Elixir ile yazılabilmesi gibi).
- Bir kullanıcı LRP'yi hiç "çalıştırmadan", sadece **mevcut sistemini dokümante etmek ve yeni sistemin nasıl olacağını tarif etmek** için de kullanabilir (Bölüm 6, Senaryo A). Bu durumda LRP kod değil, bir **metodoloji/şablon** olarak işler.

Bu üç kullanım biçimi (referans implementasyon / başka dilde implementasyon / salt dokümantasyon) aynı çekirdek kontrata dayanır, ama hiçbiri diğerini zorunlu kılmaz. Aşağıdaki bölümler bu üç kullanımın da aynı temel üzerinde nasıl durduğunu gösterir.

---

## 1. Çekirdek Kontrat (Dil-Bağımsız Şema)

Önceki tartışmalarda 9 tablodan 15'e, sonra tekrar sadeleşmeye giden bir şema evrimi yaşandı. Sadeleştirme eleştirileri (EAV'nin kaldırılması, hız katmanının ikiye indirilmesi) doğrultusunda **nihai çekirdek kontrat** şudur:

| Tablo | Amaç |
|---|---|
| `TENANT` | Çoklu kiracı izolasyonu |
| `ACTOR` | Kişi, sistem, AI agent — "kim/ne yaptı" sorusunun öznesi |
| `OBJECT` | Belge, kaynak, varlık — her "ne" (fatura, makine, not, sözleşme) |
| `EVENT` | Her olay — mail geldi, agent karar verdi, API çağrıldı |
| `RELATIONSHIP` | Varlıklar arası jenerik ilişki |
| `VERSION` | Her OBJECT değişikliğinin değişmez (immutable) geçmişi |

**ATTRIBUTE (EAV) tablosu kaldırılmıştır.** Gerekçe: hibrit şema (ayrı EAV tablosu + JSONB) iki farklı sorgu paterni anlamına geliyordu — hem geliştirici hem agent için kafa karıştırıcıydı. PostgreSQL JSONB + GIN index, EAV'in yaptığı her şeyi tek noktadan yapar. `OBJECT.metadata` (JSONB) artık tüm dinamik alanların tek adresidir. Bu, şemayı sadeleştirir ve "her şey metadata'da" diye tek bir zihinsel model bırakır — hem insan geliştirici hem agent için daha tahmin edilebilir.

**Muhasebe (Ledger) istisnadır, kusur değil.** Çekirdek jenerik kalır, ama denetim/regülasyon gerektiren domain'ler (muhasebe, stok değerleme, bordro) ayrı, katı şemalara sahiptir (`ACCOUNT`, `JOURNAL`, `JOURNAL_LINE`). Bu açıkça bir prensip olarak yazılmıştır: *"Çekirdek jenerik kalır, ama denetim gerektiren domain'ler ayrı katı şemalara sahiptir."* Bu kararın gerekçesi: bir VUK denetçisine "bu rakam neden böyle çıktı" sorusunu cevaplamak, `JOURNAL_LINE`'ın hangi kuraldan ve hangi `EVENT`'ten geldiğini gösterebilmeyi gerektirir — bu netlik jenerik bir tabloda sağlanamaz.

---

## 2. Agent-Native Olmak İçin Zorunlu Eklemeler

"Ajan ve AI uyumlu, en hızlı, en açıklanabilir" iddiası şu beş ekleme olmadan boş kalır:

| Ekleme | Neden Zorunlu |
|---|---|
| **`reasoning_trace`, `confidence_score`, `model_version`, `prompt_hash`** (her agent EVENT'inde) | İnsan ERP'sinde "kim yaptı" yeterliyken, agent ERP'sinde "neden bu kararı verdi, hangi modelle" sorgulanabilir olmalı. Bu olmadan "explainable" sloganı agent kararları için anlamsızdır. |
| **`actor_confidence`** (nullable, sadece agent actor'lar için, `VERSION` ve `EVENT`'te) | İnsan bir işlemi onayladığında %100 emindir; agent onaylarsa bu garanti değildir. Düşük confidence'lı işlemler otomatik olarak insana düşmelidir. |
| **`idempotency_key`** (her `EVENT`/`JOURNAL` insert'inde zorunlu) | Agent'lar retry yapar, insan genelde yapmaz. Bu olmadan bir agent timeout sonrası aynı işlemi iki kez işleyebilir — "en hızlı" derken "en hatalı" olma riski budur. |
| **`AGENT_CAPABILITY` / Tool Registry** (her OBJECT/TASK'ın MCP tool tanımına dönüşebilmesi) | Agent-uyumluluğunu "iddia" olmaktan çıkarıp gerçek bir entegrasyon yüzeyine dönüştürür (örn. `approve_invoice` tool'u arkada bir JOURNAL kaydı oluşturur). |
| **Opsiyonel embedding alanı** (`OBJECT.embedding`, pgvector) | Agent'ın "bu nesneye benzer ne var" diye sorgulayabilmesi için. Klasik ERP'de yoktur, ama retrieval olmadan agent akıllı çalışamaz. |

**Sıralama önemli:** Önce idempotency + confidence + reasoning_trace (agent-native temel), sonra şema sadeleştirme, sonra embedding, en son performans katmanı. "En hızlı" iddiasını ölçüm olmadan, "en açıklanabilir" iddiasını reasoning_trace olmadan yapmak, sloganı koda borçlu bırakır.

---

## 3. Sadeleştirmeler — Bilinçli Olarak Çıkarılanlar

| Çıkarılan / Ertelenen | Gerekçe |
|---|---|
| **Rust/NIF performans katmanı** | Kanıtlanmış bir çekirdek yokken performans katmanını dokümante etmek zaman kaybıdır. Önce Elixir/BEAM'in nerede yavaş kaldığı ölçülür, sonra (gerekirse) Rust'a geçilir. Dokümanda "Phase 3, ölçüm sonrası" diye açıkça etiketlenir; "yapılacakmış gibi duran ama yapılmamış" bir vaat olarak bırakılmaz. |
| **HOT/WARM/COLD üç katmanlı hız modeli → iki katmana indirilmesi** | Üç katman, üç farklı retention/storage politikası ve üç farklı kod yolu demektir — operasyonel karmaşıklığı artırır. `WARM` ve `COLD` arasındaki fark çoğunlukla "ne kadar süre sorgulanabilir kalıyor" sorusudur ve bir TTL/retention policy ile tek katmanda çözülebilir. Sadeleştirme = daha az hata yüzeyi. |
| **"9/15 tablo hiçbir domain kelimesi bilmez" katılığı** | Ledger zaten istisna; bu açık bir prensip olarak yazılır (Bölüm 1), felsefi bir yenilgi gibi gizlenmez. |
| **WAL/ring-buffer'a asenkron yazma ile "everything is traceable" sloganı arasındaki çelişki** | RAM'e yazma ile diske/WAL'a yazma arasındaki pencerede crash olursa HOT event kaybolabilir. Bu pencere ya senkron yazmayla kapatılmalı ya da dokümanda açıkça "şu kapsam dışında" diye sınırlanmalı — pazarlama metni ile mimari kararın birbirini yalanlaması engellenmelidir. |

**Genel ilke:** "Dünyanın en iyi çekirdeği" hedefi bir **planlama girdisi olarak kullanılmaz** — bu hedef sonsuz kapsam üretir (web3 + agent-native + multi-GAAP + hot-swap, hepsi aynı anda). "En iyi" bir sonuçtur, başlangıç noktası değildir.

---

## 4. Capability / Provider / Binding — Merkezi Esneklik Deseni

Bu doküman serisindeki en önemli mimari karar budur, çünkü aşağıdaki **dört farklı esneklik ihtiyacının hepsini** tek bir soyutlamayla çözer: (a) bir not alma aracını yükseltmek/düşürmek, (b) bir görevi agent'tan insana (veya tersi) almak, (c) Slack'ten kendi mesajlaşmana, Logo'dan kendi muhasebene geçmek, (d) e-fatura/web3 gibi yeni dış sistemleri eklemek.

### 4.1 Temel Prensip: "Ne" ile "Kim/Nasıl"ı Ayır

```
CAPABILITY(id, tenant_id, capability_type[note_taking|invoice_approval|
           messaging|accounting|...], interface_contract[JSONB], status)

PROVIDER(id, tenant_id, capability_id,
         provider_type[internal_md|external_app|elixir_module|
                        rust_module|php_module|agent|human],
         provider_ref[JSONB], version, status[active|standby|deprecated])

PROVIDER_BINDING(id, tenant_id, capability_id, active_provider_id,
                  bound_at, bound_by_actor_id)
```

`interface_contract` (JSONB), bir capability'i implemente eden provider'ın hangi minimum fonksiyonları desteklemesi gerektiğini tanımlar (örn. `note_taking` için `create`, `read`, `search`, `export`). Bunu bir Elixir behaviour/protokolü gibi düşünün, ama runtime'da JSONB'de tutulur — çünkü AI agent'lar da bunu okuyup uygulayabilmelidir, ve **provider_type alanı dil-bağımsızdır**: bir provider Elixir modülü, bir Rust binary'si, bir PHP servisi veya tamamen harici bir uygulama olabilir. LRP, provider'ın hangi dille yazıldığını umursamaz — sadece `interface_contract`'a uyup uymadığını umursar.

### 4.2 Örnek 1 — Not Alma Uygulaması Upgrade/Downgrade

1. **Başlangıç:** `PROVIDER(capability=note_taking, provider_type=internal_md, provider_ref={"path": "/notes/"})`
2. **Upgrade:** Yeni `PROVIDER(provider_type=external_app, provider_ref={"connector_id": "notion-uuid"})` oluşturulur; eski veriyi yeni provider'a taşıyan bir `EVENT(event_type=provider_migration)` tetiklenir; sonra `PROVIDER_BINDING.active_provider_id` yeni provider'a çevrilir.
3. Eski `.md` provider'ı **silinmez**, `status=deprecated` olarak bırakılır — çünkü `VERSION` zaten her şeyi izleme felsefesiyle tutarlı: hangi notun hangi provider'la oluşturulduğu kaybolmamalıdır.
4. **Downgrade**, tamamen aynı mekanizmanın tersidir: `active_provider_id` eski provider'a geri çevrilir, veri kaybı olmaz çünkü provider hiç silinmemiştir.

Çekirdek OBJECT/EVENT katmanı hiç değişmez — sadece `PROVIDER_BINDING` tablosunda bir foreign key değişir. Bu, "her şey takılıp çıkarılabilir" vizyonunun teknik karşılığıdır.

### 4.3 Örnek 2 — Agent ↔ İnsan Görev Değişimi

Bu zaten büyük ölçüde `TASK.assigned_actor_id` ile çözülür (`ACTOR` hem Agent hem User tipini destekler). Eksik olan, bu değişimin kuralla mı yoksa manuel mi tetiklendiğinin izlenebilir olmasıdır:

```
TASK(..., assigned_actor_id, assignment_mode[manual|auto_agent|hybrid_approval],
     reassignment_reason, previous_actor_id)
```

`reassignment_reason` kritiktir: "agent düşük confidence verdi, insana düştü" mü, yoksa "kullanıcı manuel tercih etti" mi — bu, Bölüm 2'deki `actor_confidence` ile birebir örtüşür ve ileride "hangi görev tiplerinde agent'lara güvenilir, hangilerinde değil" sorusuna process mining ile cevap vermeyi sağlar.

### 4.4 Hot-Swap Edilebilirliğin Üç Şartı

1. **Stabil interface contract** — provider değişse de capability'nin "ne yaptığı" sözleşmesi değişmez.
2. **Veri taşınabilirliği** — her provider'ın export/import formatı standart bir şemaya (OBJECT/EVENT formatına) çevrilebilmeli, yoksa downgrade veri kaybına dönüşür.
3. **Binding'in kendisi versiyonlanmalı** — `PROVIDER_BINDING` değişikliği bir `VERSION` kaydı yaratmalı; "bu görevi hangi tarihte kim/ne yapıyordu" sorusu denetim için kritiktir.

---

## 5. MIGRATION_TRACKER — Geçişin Kendisini İzleyen Katman

Capability/Provider modeli "hangi provider aktif" sorusunu çözer, ama "geçiş ne durumda, ne kadar güvenilir, ne zaman tam devreye alınmalı" sorusu ayrı bir katman gerektirir:

```
MIGRATION_TRACKER(id, tenant_id, capability_id,
                   from_provider_id, to_provider_id,
                   stage[shadow|partial|primary|full_cutover],
                   coverage_pct, discrepancy_count,
                   started_at, target_cutover_at)
```

| Stage | Ne oluyor | Örnek (Logo → kendi muhasebe) |
|---|---|---|
| `shadow` | Yeni provider sadece izliyor, eski provider gerçek işi yapıyor | LRP, Logo'dan gelen her kaydı paralelde kendi Ledger'ına yazıyor, ama hiçbir karar LRP'den çıkmıyor |
| `partial` | Yeni provider bazı düşük riskli işlemleri gerçekten yapıyor | Yeni faturalar LRP'den kesiliyor, mutabakat hâlâ Logo'dan |
| `primary` | Yeni provider ana karar mercii, eski provider yedek/doğrulama | LRP ana sistem, Logo'ya hâlâ senkron yazılıyor (geri dönüş garantisi) |
| `full_cutover` | Eski provider deprecated, sadece arşiv amaçlı duruyor | Logo bağlantısı kesildi |

**`discrepancy_count` ölçülebilir olgunluk skorudur.** `shadow`/`partial` aşamalarında iki provider'ın sonuçları (örn. bakiye) sürekli karşılaştırılır; eşleşmezse bir discrepancy event'i oluşur. Bu sayı düşmeden bir sonraki stage'e geçilemez (örn. *"son 30 günde discrepancy_count = 0 olmadan primary'e geçilemez"*).

**Discrepancy tanımı capability türüne göre değişir:**
- Muhasebe gibi sayısal capability'lerde: net ("rakam tutmuyor").
- Mesajlaşma gibi niteliksel capability'lerde: özellik paritesi sorusu. `coverage_pct`, "kaç event yakalandı" değil, "Slack'teki şu N özellikten kaçı kendi sistemde var" şeklinde tanımlanır.

**Rollback garantisi şarttır.** `primary` aşamasında bile eski provider'a senkron yazmaya devam etmek pahalı görünse de vazgeçilmezdir. `full_cutover`'a yalnızca *"son M ayda hiç discrepancy yok + hiç kritik hata yok"* şartıyla geçilir; sistem bunu otomatik önerir ama **nihai onayı her zaman insan verir.**

**ECC → LRP gibi büyük ölçekli geçişlerde** (FI/CO/MM/SD gibi birden fazla modül) tek bir global tracker yetmez — her modül/süreç için ayrı bir `MIGRATION_TRACKER` olmalıdır (satınalma `partial`'dayken muhasebe `shadow`'da olabilir). Bu, capability bazlı granüler geçişin doğal sonucudur.

> **MVP notu:** `MIGRATION_TRACKER`'ı, gerçekten bir entegrasyonu (örn. Slack) bağlayıp ikinci bir provider'a geçmeye çalıştığınız gün ekleyin. Hangi alanların gerçekten gerekli olduğu, varsayımla değil gerçek geçiş deneyimiyle netleşir.

---

## 6. OBSERVATION_MODE ve Üç Kullanım Senaryosu

LRP'nin "mevcut sisteme yerleşme" iddiası tek bir senaryo değildir; üç kategorik olarak farklı kullanım vardır — ve hepsi aynı motoru (event yakalama + süreç çıkarımı) farklı çıkış modlarıyla kullanır.

### 6.1 Senaryo A — Sadece Dokümante Et

Geçiş niyeti olmadan salt gözlem: *"sistemine dokunmuyoruz, sadece izliyoruz."*

```
OBSERVATION_MODE(id, tenant_id, scope[full_system|specific_process],
                  target_system, purpose[documentation_only|pre_migration|continuous_shadow])
```

`purpose=documentation_only` olduğunda agent hiçbir öneri/geçiş tetiklemez, yalnızca bir **süreç haritası** üretir. Bu, klasik "as-is süreç analizi" işinin otomatikleştirilmiş halidir ve **en kolay satılabilir, sıfır riskli** LRP kullanım biçimidir — müşteriye LRP'nin kendisini hiç anlatmaya gerek kalmaz.

### 6.2 Senaryo B — ECC → HANA (LRP "Geçişin Hafızası")

LRP burada bir geçiş hedefi değildir (ikisi de SAP'tır, capability swap'ı değildir). Asıl risk, ECC'de birikmiş, hiçbir yerde yazılı olmayan özelleştirmelerin geçişte kaybolmasıdır. LRP'nin değeri:
1. ECC akışını `OBSERVATION_MODE` ile gölge modda izleyip gerçek süreç akışını çıkarmak.
2. HANA sonrası aynı izlemeyi tekrarlayıp iki süreç haritasını karşılaştırmak: *"şu adım kayboldu mu / değişti mi?"*

Bu, Bölüm 5'teki `discrepancy_count` mantığının migration-projesi versiyonudur — ama fark iki provider arasında değil, **iki ERP versiyonu arasındaki** iki snapshot arasındadır. Bu, mevcut SAP danışmanlık müşterilerine LRP'yi hiç göstermeden satılabilen ayrı bir hizmet hattı açar.

### 6.3 Senaryo C — ECC → LRP Tabanlı Sisteme Yavaş Geçiş

Bu, Bölüm 5'teki `MIGRATION_TRACKER` senaryosudur, ama büyük ölçekte ve modül bazlı granülerlikle.

### 6.4 Ortak Motor, Farklı Çıkış

| Senaryo | Çıkış Modu |
|---|---|
| A — Dokümantasyon | Rapor üret, dur |
| B — ECC → HANA | İki snapshot'ı karşılaştır, fark raporu üret |
| C — ECC → LRP | Gerçek capability swap'a kadar götür |

Bu sıralama aynı zamanda ticari bir kademe sunar: önce risksiz dokümantasyonla güven kazanılır, sonra geçiş doğrulama hizmeti satılır, en sona asıl büyük taahhüt (tam migrasyon) bırakılır.

---

## 7. Onboarding Akışı (Kullanıcının Gördüğü Yüz)

Tüm yukarıdaki mimari, kullanıcı için şu basit akışa indirgenir:

1. **"Sıfırdan mı, mevcut bir sistemi mi geliştiriyorsun?"** — iki yol ayrımı.
2. **Mevcut sistem seçilirse:** LRP paralelde (gölge modda, `OBSERVATION_MODE`) gelişir; mevcut sistem gerçek işi yapmaya devam eder.
3. **Olgunluk eşiğine ulaşınca** LRP devreye alınmaya başlanır (Bölüm 5'teki `MIGRATION_TRACKER` akışı).
4. **Devreye alındıktan sonra** agent, işleyişten ve gelen maillerden öğrenip gelişme önerileri sunar.

**Kritik açık nokta — "olgunluk" nasıl ölçülür:** Bu, sübjektif bir kullanıcı kararına bırakılmamalı, somut bir `MATURITY_SCORE` olarak hesaplanmalı (örn. coverage bazlı: "olayların %X'i artık EVENT olarak yakalanıyor"; veya confidence bazlı: "agent'ın süreç çıkarımı son N olayda %X doğrulukla onay aldı"; veya zaman bazlı: "30 gün kesintisiz paralel veri toplandı"). Kullanıcıya dashboard'da somut bir ilerleme çubuğu olarak gösterilmelidir: *"LRP şu an sürecinizin %72'sini görüyor, %90'a ulaşınca devreye almayı önereceğiz."*

**Gölge fazda agent öneri üretmemeli, sadece gözlemlemeli** (veya açıkça "preview/sandbox" etiketiyle işaretlenmeli) — aksi halde eksik veriyle yanlış öneri üretip güven kaybettirir, ve kullanıcı "hangi sistem gerçek karar mercii" konusunda kafası karışır.

**Mail'den anlama, ilk sürümde insan onaylı sınıflandırma olmalı:** Agent "bu maili Fatura Onayı olarak sınıflandırdım, doğru mu?" diye sorar, kullanıcı onaylar/düzeltir. Bu hem agent eğitimi için veri üretir (Bölüm 2'deki `reasoning_trace`/`confidence` ile birebir örtüşür) hem de erken aşamada yanlış sınıflandırmanın güven kırmasını önler.

---

## 8. Dış Sistem Uyumluluğu — Tek Bir İlkeyle Üç Soruya Cevap

Sorulan üç soru ("web3 uyumlu mu", "e-fatura uyumlu mu", "birçok sistem birbirine bağlanabilir mi") aynı mimari kararla cevaplanır:

> **Çekirdek (Bölüm 1 + Ledger) hiçbir dış sistemi bilmez. Her dış sistem ayrı bir `integrations/*` modülünde, ortak bir Connector/Adapter kontratı üzerinden OBJECT/EVENT formatına çevrilerek çekirdeğe girer.**

### 8.1 E-Fatura

Büyük ölçüde zaten uyumlu: `EVENT(source="e-fatura")`, `OBJECT(type="Document")` faturayı zaten karşılar. Eksik olan, GİB'in UBL-TR XML şemasına map eden bir adapter'dır — bu çekirdeğe değil, ayrı bir `integrations/efatura` modülüne konur. `OBJECT.metadata` içine `gib_uuid`, `ettn`, `signature_status` gibi alanlar eklenir.

### 8.2 Web3

"Web3 ekleyeyim" çok geniş bir ifadedir; somutlaştırılmalıdır: **`VERSION` tablosundaki immutable hash zinciri zaten blockchain'in "append-only, hash-linked" mantığına yakındır.** `VERSION.object_snapshot` hash'i periyodik olarak bir chain'e anchor edilerek "bu kayıt şu tarihte böyleydi, sonradan değiştirilmedi" kanıtı üretilebilir — bu, denetimde "tamper-proof audit trail" iddiasına gerçek bir teknik dayanak katar. Akıllı kontrat/token/wallet entegrasyonu gibi geniş kapsamlı şeyler şimdilik eklenmez; çekirdeğin "web3-aware" olması gerekmez, sadece "hash/anchor edilebilir" olması yeterlidir.

### 8.3 Çoklu Sistem Bağlantısı

Üç eksik parça tamamlanmalı:

1. **Standart Connector kontratı:** `CONNECTOR(id, tenant_id, type, config[JSONB], auth_method, status)` + her connector'ın "her olayı LRP EVENT formatına çeviren" tek bir `transform/1` benzeri fonksiyon kontratı uygulaması. (MCP bu modeli zaten kısmen sağlar.)
2. **Outbound event yayını:** Sistem şu an sadece dinliyor (inbound); dışarıya da yayın yapabilmeli — `EVENT_SUBSCRIPTION(actor_id, event_type_pattern, webhook_url, secret)`.
3. **Şema versiyonlama sözleşmesi:** Dış sistemler `OBJECT.type` veya `RELATIONSHIP.relationship_type` enum'larına bağımlı olacaktır; bunlar değiştiğinde dış entegrasyonlar kırılmasın diye API versiyonlama (`/api/v1/events`) ve "type" alanlarının silinmeden sadece deprecated işaretlenmesi kuralı konur.

---

## 9. Yürütme Disiplini — Kapsamın Büyümesini Durdurmak

Bu doküman serisi boyunca yaşanan asıl risk mimari değil, **kapsam/yürütme dengesidir.** Şema birkaç tablodan onlarca kavrama (Ledger, ADR, Capability/Provider, MIGRATION_TRACKER, web3, agent-native) çıktı; her tur dokümanı büyüttü. Bu büyüme şu kurallarla sınırlanır:

1. **"En iyi çekirdek" hedefi planlama girdisi olarak kullanılmaz.** Sonsuz kapsam üretir. "En iyi" bir sonuçtur, başlangıç noktası değildir.
2. **Tek gerçek müşteri, tek gerçek acı noktası önce çözülür.** Mevcut SAP danışmanlık ilişkileri kullanılarak, bir müşterinin tek somut sorunu (örn. "fatura onay süreci yavaş") yalnızca `TENANT`, `ACTOR`, `OBJECT`, `EVENT` ile çözülür — Capability/Provider, MIGRATION_TRACKER, web3 ilk dilimde yoktur.
3. **Mimari gerçek acıdan türetilir, varsayımdan değil.** Bu dokümandaki her ek (idempotency, embedding, capability registry) doğrudur ama "ileride lazım olabilir" varsayımına dayanır. Gerçek bir kullanım 100 kez çalıştırılınca hangi tablo gerçekten yetersiz kalıyor — o öğrenilir, sonra eklenir.
4. **AgentAndBot, ilk 3-6 ay "platform" değil "uygulama" olarak konumlandırılır.** "Object Graph işletim sistemi" anlatısı satılabilir bir ürün değil, bir araştırma projesi gibi durur. "SAP danışmanlık müşterisinin onay sürecini otomatikleştiren AI agent" satılabilir bir şeydir; LRP bunun arkasında sessizce çalışan motordur.
5. **Dokümantasyon hızı koddan ayrılmaz; kod yazıldıkça doküman yazılır, tersi değil.**

**Somut ilk adım:** `TENANT`, `ACTOR`, `OBJECT`, `EVENT` migration'larını yazıp, bir e-postanın inbox'a düşüp bir `Document` OBJECT'i oluşturduğu tek bir akışı çalıştırın. Bu dört tablo dışında hiçbir şeye dokunulmaz. Bu çalışınca, eksikler dokümandan değil gerçek hatadan öğrenilir.

---

## 10. Uygulama Sırası (Özet)

| Sıra | Adım | Kapsam |
|---|---|---|
| 1 | Çekirdek demo | `TENANT/ACTOR/OBJECT/EVENT` + basit inbox, tek akış uçtan uca |
| 2 | Agent-native temel | `idempotency_key`, `actor_confidence`, `reasoning_trace` |
| 3 | Onboarding iskeleti | Sihirbaz (sıfırdan/mevcut) + coverage sayacı (`MATURITY_SCORE` v0) |
| 4 | Şema sadeleştirme | EAV kaldırılır, hız katmanı ikiye iner |
| 5 | İlk gerçek entegrasyon | Tek bir Connector (örn. Slack veya e-posta) + insan onaylı sınıflandırma |
| 6 | Capability/Provider/Binding | Sadece gerçek bir upgrade/downgrade ihtiyacı doğunca |
| 7 | MIGRATION_TRACKER | Sadece ikinci bir provider'a fiilen geçilmeye çalışıldığı gün |
| 8 | Embedding/semantic katman | Agent retrieval ihtiyacı somutlaşınca |
| 9 | Performans katmanı (Rust vb.) | Yalnızca ölçümle "Elixir burada yetersiz" kanıtlandıktan sonra |
| 10 | Web3/e-fatura/diğer dış sistemler | Connector kontratı üzerinden, çekirdeğe dokunmadan, talep geldikçe |

---

*Bu doküman, önceki LRP mimari taslaklarının üzerine inşa edilmiş, eleştiri turlarıyla sadeleştirilmiş ve dil-bağımsız hale getirilmiş güncel (v2) versiyonudur. LRP'nin kendisi bir runtime değil bir kontrattır; Elixir bir referans implementasyondur, zorunluluk değildir.*
