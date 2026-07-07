# DOX framework — lib/lrp_web/

- Parent: [LRP root AGENTS.md](../../AGENTS.md)
- Scope: Phoenix LiveView web katmani — router, layout, LiveView sayfalari, component'lar

## Local Contract

Bu dizin LRP'nin **web yüzüdür**: Phoenix LiveView ile yapilandirilmis, backend'e `LRP` public API modulu üzerinden erisen tum arayuz kodu burada yasr.

**Kritik hatirlatma**: `LRP.Repo`'ya dogrudan erisim yasaktir. Tum veri islemleri `lib/lrp.ex` public API uzerinden yapilir.

---

## Mimari Kurallar

1. **LRP.Repo yasagi**: Hiçbir LiveView, component veya controller dosyasi `LRP.Repo`'ya dogrudan erisemez. Tum veri erisimi `LRP` modulu (lrp.ex) uzerinden yapilir.

2. **LiveView-first**: Tum sayfalar `LiveView` olarak yapilandirilir. Dead render icin `live_session` veya statik `:live` route kullanilir.

3. **Tenant baglami**: Auth sistemi yok; tenant `List.first(LRP.list_tenants())` ile belirlenir. Auth eklendiginde session/conn bazli olacaktir.

4. **CSS dosyasi**: `priv/static/assets/css/app.css` tek dosya, Node.js derleme pipeline yok. CSS degiskenleri + dark sidebar + accent tema.

5. **Phoenix bağımlılıkları**: `phoenix ~> 1.7`, `phoenix_pubsub ~> 2.0`, `phoenix_live_view ~> 1.0`, `phoenix_html ~> 4.0`, `bandit ~> 1.0`.

---

## Dosya İndeksi

| Dosya | Modül | Sorumluluk |
|---|---|---|
| `lrp_web.ex` | `LRPWeb` | Web modülü + makrolar (html, live_view, live_component, router, verified_routes) |
| `endpoint.ex` | `LRPWeb.Endpoint` | Phoenix.Endpoint — LiveView socket, Plug.Static, Plug.Session |
| `router.ex` | `LRPWeb.Router` | Tum route tanimlari (Inbox, Workspace, Agents, Studio, Apps, Admin, Dashboard, Search) |
| `telemetry.ex` | `LRPWeb.Telemetry` | Supervisor placeholder |
| `errors.ex` | `LRPWeb.ErrorHTML/ErrorJSON` | Hata sayfalari |
| `components/layouts.ex` | `LRPWeb.Layouts` | Root layout + App layout (dark sidebar, AgentBar entegrasyonu) |
| `components/agent_bar.ex` | `LRPWeb.Components.AgentBar` | Sag kenarda kaydirilan agent chat paneli (LiveComponent) |
| `components/agent_card.ex` | `LRPWeb.Components.AgentCard` | Agent kart gorsel bileseni (LiveComponent) |
| `live/page_live.ex` | `LRPWeb.PageLive` | `/` → `/inbox` yonlendirme |
| `live/placeholder_live.ex` | `LRPWeb.PlaceholderLive` | Uygulama yapilmamis sayfalar icin placeholder |
| `live/inbox_live/index.ex` | `LRPWeb.InboxLive.Index` | E-posta listesi |
| `live/inbox_live/show.ex` | `LRPWeb.InboxLive.Show` | E-posta detay + event sidebar |
| `live/approvals_live/index.ex` | `LRPWeb.ApprovalsLive.Index` | Bekleyen onay kuyrugu |
| `live/search_live/index.ex` | `LRPWeb.SearchLive.Index` | Global arama (nesne, event, gorev) |
| `live/dashboard_live/index.ex` | `LRPWeb.DashboardLive.Index` | Sistem dashboard — sayaclar + event feed |
| `live/agents_live/index.ex` | `LRPWeb.AgentsLive.Index/Show` | Agent listesi + detay/AgentContext log |
| `live/admin_live/index.ex` | `LRPWeb.AdminLive.Index` | Admin panel — EventSubscription + tenant info |
| `live/studio_live/index.ex` | `LRPWeb.StudioLive.Index` | Aktif proje listesi |
| `live/studio_live/new.ex` | `LRPWeb.StudioLive.New` | 3 adimli proje olusturma sihirbazi |
| `live/studio_live/show.ex` | `LRPWeb.StudioLive.Show` | Proje detay — info, software modules, event feed |

---

## Route Haritasi

| Yol | LiveView | Faz | Durum |
|---|---|---|---|
| `/` | `PageLive` (redirect `/inbox`) | 1a | ✅ |
| `/inbox` | `InboxLive.Index` | 1a | ✅ |
| `/inbox/mail/:id` | `InboxLive.Show` | 1b | ✅ |
| `/inbox/approvals` | `ApprovalsLive.Index` | 1b | ✅ |
| `/search` | `SearchLive.Index` | 1b | ✅ |
| `/dashboard` | `DashboardLive.Index` | 1c | ✅ |
| `/agents` | `AgentsLive.Index` | 1c | ✅ |
| `/agents/:id` | `AgentsLive.Show` | 1c | ✅ |
| `/admin` | `AdminLive.Index` | 1c | ✅ |
| `/workspace` | `PlaceholderLive` | 1a | ✅ Placeholder |
| `/workspace/calendar` | `PlaceholderLive` | 1a | ✅ Placeholder |
| `/workspace/notes` | `PlaceholderLive` | 1a | ✅ Placeholder |
| `/workspace/todos` | `PlaceholderLive` | 1a | ✅ Placeholder |
| `/studio` | `StudioLive.Index` | 2 | ✅ |
| `/studio/new` | `StudioLive.New` | 2 | ✅ |
| `/studio/:id` | `StudioLive.Show` | 2 | ✅ |
| `/apps` | `PlaceholderLive` | 1a | ✅ Placeholder |

---

## Static Assets

| Yol | Icerik |
|---|---|
| `priv/static/assets/css/app.css` | Tek CSS dosyasi — CSS degiskenleri, dark sidebar (#0f172a), accent (#6366f1), dashboard/agent/admin/mail/search/approval stilleri, agent bar, offline banner |

---

## Yeni Sayfa Eklerken

1. Bu Dosya İndeksi tablosuna ekle.
2. Route Haritasi tablosuna ekle.
3. `lib/lrp_web/router.ex`'e route ekle.
4. Sidebar navigasyonu icin `layouts.ex`'te `nav_path`/`nav_icon` ekle (yeni ana menu ise).
5. Gerekirse `lib/lrp.ex`'e yeni API fonksiyonu ekle (asla dogrudan Repo).
6. CSS'i `priv/static/assets/css/app.css`'e ekle.
7. Compile (`mix compile`) + test (`mix test --exclude external`) dogrulamasi yap.
8. Bu AGENTS.md'yi ve implementation_plan.md'yi guncelle.

- 🔴 **Software Engineering Principles**: Geliştirmeye başlamadan önce mutlaka [ENTERPRISE-ENGINEERING-PRINCIPLES.md](file:///B:/DEV/ENTERPRISE-ENGINEERING-PRINCIPLES.md) dosyasını okuyun, projenin tier seviyesini belirleyin ve kurallara uyun. Eğer bu kurallar dışında bir uygulama yapılacaksa bu durum `AGENTS.md` dosyasında belirtilmelidir; gerekirse `ENTERPRISE-ENGINEERING-PRINCIPLES.md` dosyası proje klasörüne kopyalanıp özelleştirilmiş bir versiyonu oluşturulabilir. Değişiklik küçükse sadece `AGENTS.md` dosyasında belirtilmesi yeterlidir.
