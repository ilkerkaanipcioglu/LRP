# LRP Platform — Güncellenmiş Tam Mimari Plan

> Mevcut LRP Core (37 test ✅) üzerine kurulu.
> Web (LiveView) → Desktop (Tauri) → Mobile (React Native + Phoenix Channels) → CLI

## User Review Required: Phase 3 — Workspace (Takvim, Not & Todo) Planı

> [!IMPORTANT]
> **Faz 3 (Workspace) için önerilen teknik tasarım detayları aşağıdaki gibidir. Lütfen onaylayın:**
> 1. **Takvim Görünümü (`/workspace/calendar`)**:
>    - Aylık takvim grid arayüzü kurulacaktır. 
>    - Takvim verileri hem `OBJECT(type: "CalendarEvent", metadata: %{"due_date" => ...})` nesnelerinden hem de teslim tarihi set edilmiş LRP `ProcessTask` (süreç görevleri) kayıtlarından çekilecektir.
> 2. **Markdown Notlar (`/workspace/notes` & `/workspace/notes/:id`)**:
>    - Not listeleme, arama ve yeni not oluşturma ekranı.
>    - `/workspace/notes/:id` altında tam ekran Markdown not editörü kurulacaktır.
>    - Her not kaydedildiğinde LRP `Version` API (`LRP.commit_version/3`) tetiklenerek Git benzeri sürüm commit geçmişi tutulacak ve kullanıcı notun eski sürümlerine geri dönebilecektir.
> 3. **Görev Listesi (`/workspace/todos`)**:
>    - Tüm aktif `ProcessTask` (todolar) listelenecektir.
>    - Proje filtreleme dropdown'ı eklenecektir. Bu sayede sadece seçili projeye ait (`Relationship` ile bağlı) todolar süzülebilecektir.
> 4. **LRP API Entegrasyonları**:
>    - `LesProjectToLive` modülü altında `create_note/2`, `get_note!/1`, `list_notes/1`, `commit_note_version/4`, `list_calendar_events/1` ve `list_todos/2` (proje filtreli) sorguları yazılacaktır.

---

## Ana Menü — Sidebar

```
📥  Inbox          ← mail + chat + onay
📅  Workspace      ← takvim + not + todo
🤖  Agents         ← agent hub
🎬  Studio         ← proje geliştirme sihirbazı   [eski: LRP Core]
📱  Uygulamalar    ← tenant apps (widget tabanlı)
─────────────────────────────────────────────
⚙️  Admin          ← sadece IT yöneticisi görür
👤  [Kullanıcı]
```

---

## MODÜL 1 — INBOX (Mail + Chat + Onay + Kişiler)

### Vizyon
Birden fazla e-posta kutusu bağlanır. Mail açılınca yanında bir sidebar chat açılır —
ekip tartışması orada yapılır, "Reply All" biter. Son hali maile döner.
DM + grup chat WhatsApp/Telegram tarzı. Agentlarla da aynı chat'te konuşulur.
Onaylar da buraya düşer.

### LRP Mapping (yeni tablo YOK)
```
Mailbox             → OBJECT(type: "Mailbox")
E-posta             → OBJECT(type: "Document") + EVENT(email_received)
Sidebar Thread      → OBJECT(type: "Thread") + Relationship → Document: "discussion_of"
Chat mesajı         → EVENT(source: "chat", event_type: "message_sent")
DM / Grup konuşma   → OBJECT(type: "Conversation")
Onay isteği         → ProcessTask(state: "approval_pending", actor_confidence < 0.7)
Kişi                → OBJECT(type: "Contact")
```

### Sayfalar
```
/inbox                    → ana görünüm
/inbox/:mailbox_id        → seçili mailbox
/inbox/mail/:id           → mail detay + sidebar thread
/inbox/chat               → DM + grup listesi
/inbox/chat/:conv_id      → konuşma detayı
/inbox/approvals          → bekleyen onaylar
/inbox/contacts           → kişiler
/search?q=               → global arama (Faz 1b)
```

---

## MODÜL 2 — WORKSPACE (Takvim + Not + Todo)

### Vizyon
Takvim, not ve todo tek çatı altında. Mail/chat/agenttan gelen görevler otomatik buraya
düşer. Proje bağlamında filtrelenebilir.

### LRP Mapping
```
Takvim etkinliği  → OBJECT(type: "CalendarEvent") + ProcessTask(due_date)
Not               → OBJECT(type: "Note") + Version (commit geçmişi)
Todo              → ProcessTask(state: "todo", assigned_actor_id)
Proje bağlantısı  → Relationship(Note/Task → Project: "belongs_to")
```

### Sayfalar
```
/workspace            → takvim (varsayılan)
/workspace/calendar   → aylık/haftalık/günlük görünüm
/workspace/notes      → not listesi + editör
/workspace/notes/:id  → not detay + versiyon geçmişi
/workspace/todos      → todo listesi + proje filtresi
```

---

## MODÜL 3 — AGENTS (Agent Hub)

### Vizyon
Agentların yönetim merkezi. Agentlar her sayfada çalışır ama ayarları burada.
Her agentin mailbox bağlantısı, proje ataması, güven skoru, karar log'ları burada.

### Agent Konuşma Kalıcılığı
```
Agent konuşması   → OBJECT(type: "Conversation")
Her mesaj         → EVENT(source: "agent_chat", event_type: "message_sent")
Sayfa değişince   → konuşma LRP'de yaşıyor, kaybolmaz
Browser yenilense → kaldığı yerden devam (LRP'den yüklenir)
```
AgentContext tablosuyla tam uyumlu. Ek tablo gerekmez.

### Global Agent Bar
Sayfanın sağında her yerden açılabilen kalıcı panel.
Mail okurken, kod yazarken, rapor incelerken — agent hep orada.

### LRP Mapping
```
Agent               → Actor(type: "Agent")
Konfigürasyon       → AgentCapability (MCP tool registry)
Karar kaydı         → AgentContext(reasoning_trace, confidence_score)
Mailbox bağlantısı  → Relationship(Actor → Mailbox: "monitors")
Proje ataması       → Relationship(Actor → Object[Project]: "manages")
```

### Sayfalar
```
/agents                   → agent listesi
/agents/new               → yeni agent kurulumu
/agents/:id               → detay + ayarlar
/agents/:id/logs          → AgentContext log'ları ("neden bu kararı verdi")
/agents/:id/capabilities  → MCP araç listesi
```

---

## MODÜL 4 — STUDIO (Proje Geliştirme Sihirbazı)

### Vizyon
Yeni LRP projesi başlatmak veya mevcut sistemi LRP'ye bağlamak için sihirbaz.
LRP ile bir yazılım geliştirebileceğimiz gibi bir proje blueprint'i (mimari tasarımı, akış şemaları veya dokümantasyon) de oluşturabiliriz. Aynı zamanda birden fazla yazılım geliştirmesi ve birden fazla blueprint yan yana yönetilebilir.
Her projeye özel bir e-posta adresi ve agent atanır. İnsanlar o maile yazar, agent okur, LRP'ye yazar, kodu/blueprint'i üretir veya onay ister.

### Proje Geliştirme Akışı
```
1. KAYNAK
   ☐ Mevcut sistem var  → GitHub/klasör ver → Analyzer çalışır
   ☐ Sıfırdan           → boş başlar

2. MAİL
   projex@lrp.harezm.com (veya kendi domain)
   → Bu mail bu projeye özel Agent'a atanır
   → LRP.Inbox.ingest_email ile otomatik okunur

3. PROJE KLASÖRÜ
   → Agent'ın ürettiği dosyalar burada birikir
   → Her değişiklik: LRP.commit_version (versiyon geçmişi)

4. ÇALIŞMA DÖNGÜSÜ
   İnsanlar maile yazar (fikir, kod, "şunu yap")
       ↓
   LRP.Inbox.ingest_email → EVENT(email_received)
       ↓
   Agent okur → LRP.log_agent_context (karar kaydı)
       ↓
   actor_confidence yüksekse → direkt uygular
   actor_confidence düşükse  → ProcessTask(approval_pending) → Inbox'a düşer
       ↓
   Çıktı: Elixir / Markdown / istenilen dil

5. ENTEGRASYON
   Aynı şirket (tenant) altındaki tüm projeler max entegrasyon ile çalışır ancak aynı database'i paylaşmak zorunda değildir.
   Aynı proje altındaki uygulamalar (alt projeler) ise aynı database'i paylaşır.
```

### LRP Mapping (yeni tablo YOK)
```
Proje               → OBJECT(type: "Project")
Yazılım Geliştirme  → OBJECT(type: "Software") + Relationship → Project: "contains_software"
Blueprint / Şablon  → OBJECT(type: "Blueprint") + Relationship → Project: "contains_blueprint"
Proje maili         → OBJECT(type: "Mailbox") + Relationship → Project: "dedicated_to"
Proje agenti        → Actor(type: "Agent") + Relationship → Project: "manages"
Proje klasörü       → OBJECT(type: "Folder") + Relationship → Project: "belongs_to"
                      (Not: Klasör yerel olabileceği gibi Google Drive, Notion, Slack veya gelecekte eklenecek 
                      onlarca 3. parti SaaS uygulaması LRP.Capability.Manager aracılığıyla "external_app" 
                      sağlayıcısı olarak hot-swap bağlanabilir)
Proje→proje         → Relationship(Project → Project: "integrates_with")

### Bilet Sistemi (Ticket System) Entegrasyonu
Bilet / İş Kartı    → OBJECT(type: "Ticket", metadata: {ticket_number, status, priority})
- **E-Posta Entegrasyonu**: Gelen her mail (`Document`) için otomatik bir bilet numarası (`TCK-100X`) atanır ve `Relationship(Ticket → Document: "generated_by_mail")` ile bağlanır.
- **Todo Entegrasyonu**: Biletin çözülmesi için atanan görevler (`ProcessTask`) `Relationship(Ticket → ProcessTask: "contains_task")` ilişkisiyle bağlanır.
- **Studio Entegrasyonu**: Geliştirilen yazılım modülü veya blueprint maddeleri `Relationship(Ticket → Software/Blueprint: "references_source")` ile biletlere referans verilir.
```

### Sayfalar
```
/studio                        → aktif proje listesi
/studio/new                    → sihirbaz (3 adım)
/studio/:id                    → proje detay (mail + agent + dosyalar)
/studio/:id/versions           → commit geçmişi
/studio/:id/tasks              → proje görevleri
```

---

## MODÜL 5 — UYGULAMALAR (Tenant Apps — Widget Sistemi)

### Vizyon
LRP ile yazılan uygulamalar burada listelenir. Kullanıcı kendi ekranını widget'lardan
oluşturur. Dinamik kod injection YOK — konfigürasyon tabanlı, güvenli, hızlı.

### Widget Sistemi
```
Ekran tanımı  → OBJECT(type: "AppScreen", metadata: {layout, widgets})
Widget türleri:
  ObjectList  → tip/filtre/kolon seçer, listeyi gösterir
  Chart       → event veya item agregasyonu
  Form        → OBJECT oluştur/güncelle formu
  KPI         → tek sayı (ör: bu ay gelir)
  EventFeed   → canlı event akışı

Kullanıcı örneği:
  "Müşteri Listesi" ekranı:
  → Widget: ObjectList
  → Filter: type=Party, subtype=Customer
  → Kolonlar: name, email, last_event
  → Kaydet → ekran hazır, kod yok
```

Kod injection yok. Sandbox sorunu yok. Başka tenant etkilenmez.

### Sayfalar
```
/apps                  → uygulama listesi (sidebar'a da yansır)
/apps/:id              → uygulama anasayfası (widget grid)
/apps/:id/screen/:sid  → özel ekran
/apps/builder          → widget ekran builder
```

---

## MODÜL 6 — ADMIN (IT Yöneticisi)

Sadece yetkili kullanıcı görür.

### Sayfalar
```
/admin                 → genel bakış
/admin/connectors      → bağlı sistemler (Gmail, Outlook, SMTP)
/admin/rules           → PostingRule, Policy yönetimi
/admin/tenants         → multi-tenant yönetimi (super admin)
/admin/webhooks        → EventSubscription listesi
```

---

## MODÜL 7 — DASHBOARD (Sistem Durumu)

```
/dashboard             → sayaçlar + canlı event feed
```

LRP.count_all/0 + Broadway → LiveView PubSub → canlı akış.
Admin'e gömülü de olabilir.

---

## Teknik Detaylar

### Offline / Bağlantı Kesildi
```
LiveView built-in phx-disconnected sınıfı kullanılır:
  → Bağlantı kesildi → sarı banner (bağlantı bekleniyor)
  → Mail listesi: son render'dan okunabilir (read-only)
  → Yazma → "Bağlantı gerekli" uyarısı
  → Geri gelince → otomatik reconnect + state sync
Karmaşık offline sync gerekmez. 20 satır CSS + basit banner.
```

### Mobile — Phoenix Channels (REST değil)
```
REST: sadece authentication için (/api/auth/*)
Phoenix Channels: her şey için

react-native-phoenix paketi (olgun, production-ready)
  → Gerçek zamanlı onay bildirimleri
  → Agent mesajları anında gelir
  → Mail bildirimleri anında gelir
  → Polling yok, pil dostu
```

### Global Arama
Faz 1b'de açılır.
```
/search?q=bosch
  Sonuçlar:
  → OBJECT'ler (Bosch GmbH müşteri kartı)
  → EVENT'ler (Bosch'tan gelen mailler)
  → PROCESS_TASK'lar (Bosch ile ilgili onaylar)
  → Not'lar (Bosch toplantı notu)

Faz 1b: PostgreSQL FTS (ILIKE + ts_vector)
Faz 3+:  pgvector semantic search (embedding alanı schemas.ex'te hazır)
```

---

## Faz Planı

### Faz 1a — İskelet (1-2 hafta)
```
[ ] Phoenix.Endpoint + Router + Layout
[ ] Sidebar iskelet (statik, 5 menü)
[ ] /inbox → mail listesi (detay yok)
[ ] LRP.Repo + Phoenix.PubSub bağlantısı
[ ] Offline banner (phx-disconnected)
Demo: "Açılıyor ve Bağlanıyor"
```

### Faz 1b — İlk Değer (1-2 hafta)
```
[ ] Mail detay + sidebar chat (Thread + EventLog)
[ ] /inbox/approvals → onay kuyruğu
[ ] Global Agent Bar (kalıcı konuşma - LRP Conversation Object)
[ ] /search → global arama (PostgreSQL FTS)
Demo: "Gerçek iş yapılıyor"
```

### Faz 1c — Görünürlük (1-2 hafta)
```
[ ] /dashboard → event feed + LRP.count_all sayaçları
[ ] /agents → liste + AgentContext log'ları
[ ] /admin → Connector listesi
Demo: "Sistem ne yapıyor görünüyor"
```

### Faz 2 — Studio Sihirbazı (2-3 hafta)
```
[ ] /studio/new → 3 adımlı sihirbaz
[ ] Proje mailbox oluşturma + Connector bağlama
[ ] Proje agenti atama + Capability kayıt
[ ] Mail → ingest → ProcessTask → onay döngüsü
[ ] /studio/:id → proje detay sayfası
```

### Faz 3 — Workspace (2 hafta)
```
[ ] /workspace/calendar (ProcessTask due_date entegrasyonu)
[ ] /workspace/notes (Version geçmişi + Markdown)
[ ] /workspace/todos (proje bağlam filtresi)
[ ] Proje → Note/Task Relationship bağlantısı
```

### Faz 4 — Uygulamalar / Widget Builder (2 hafta)
```
[ ] AppScreen OBJECT + metadata widget schema
[ ] ObjectList, KPI, Chart, Form widget'ları
[ ] /apps/builder → sürükle-bırak (veya form tabanlı)
[ ] les_project_to_live ekranı burada görünür
```

### Faz 5 — Desktop + Mobile
```
[ ] Tauri wrap (Faz 1 bitince ~1 hafta)
    → tauri.conf.json + sistem tepsisi + OS bildirimi
[ ] React Native (MVP kanıtlandıktan sonra)
    → Phoenix Channels (react-native-phoenix)
    → Onay bildirimi + mail okuma + agent chat
    → Authentication için minimal REST /api/auth/*
```

### CLI — Her Faz Boyunca
```bash
mix lrp.status              # tablo sayaçları
mix lrp.events [tenant_id]  # son eventler
mix lrp.tasks [tenant_id]   # açık görevler
mix lrp.agent.run [id]      # agenti manuel tetikle
mix lrp.studio.new          # proje sihirbazı (CLI)
mix lrp.inbox.ingest [file] # test e-postası gönder
mix lrp.search [q]          # global arama CLI
```

---

## Mevcut LRP Koduyla Uyum Tablosu

| Özellik | Kullanılan LRP | Durum |
|---|---|---|
| Mail alma | `LRP.Inbox.ingest_email/2` | ✅ Hazır |
| Event kayıt | `LRP.log_event/1` | ✅ Hazır |
| Chat mesajı | `LRP.log_event/1` (source: "chat") | ✅ Hazır |
| Onay isteği | `LRP.create_process_task/1` | ✅ Hazır |
| Agent kararı | `LRP.log_agent_context/1` | ✅ Hazır |
| Not + versiyon | `LRP.create_object + commit_version` | ✅ Hazır |
| Widget ekranı | `LRP.create_object` (type: "AppScreen") | ✅ Hazır |
| Proje maili | `LRP.relate(Actor → Mailbox: "monitors")` | ✅ Hazır |
| Global arama | PostgreSQL FTS (Ecto `ilike` / `ts_vector`) | ⚠️ Eklenecek |
| Canlı feed | Broadway → `Phoenix.PubSub.broadcast` | ⚠️ Eklenecek |
| Agent konuşma | `OBJECT(Conversation) + EVENT(message_sent)` | ⚠️ Açıkça eklenmeli |
| Offline banner | `phx-disconnected` CSS | ⚠️ 20 satır |
| Mobile push | Phoenix Channels | ⚠️ Faz 5 |

**Yeni veritabanı tablosu gerekmez. 11 tablo tüm özellikleri karşılar.**
