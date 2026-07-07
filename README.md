# LRP — AI-native Enterprise Operating System

> For the full vision and where LRP is going, see **[VISION.md](VISION.md)**.
>
> This document describes **current implementation status** — what is actually built and what is not yet.

---

## Design Principles

1. **The core stays generic.** The 9-table Object Graph has no domain knowledge (no "customer", "invoice", "stock" keywords in the schema).
2. **Regulatory domains get hard schemas.** Accounting (VUK/IFRS), payroll, and stock valuation require strict schemas and immutable audit trails. These live in separate layers — not as exceptions, but by design.
3. **Everything that needs to be auditable is written before acknowledged.** HOT events (RAM-only) are a performance trade-off acknowledged in the implementation status table below.
4. **Performance optimizations (Rust/NIF, pgvector indexing) are applied after measurement**, not before. The core is Elixir/BEAM first.

---

## What LRP Is (Today)

LRP (Lightweight Resource Planning) is an Elixir/SQLite3 based **Object Graph Engine** —
a generic, event-driven core that eliminates domain-specific tables and replaces them with
9 universal tables. It is designed to be the foundation on which AI-native enterprise
applications are built.

> **Database Strategy:**
> - **Development / PoC:** SQLite3 (`ecto_sqlite3`) — zero setup, runs anywhere, used in all current tests.
> - **Production:** PostgreSQL — required for Row-Level Security (RLS), pgvector (embeddings), and CQRS read model performance. The migration file already includes the RLS `CREATE POLICY` statements; they activate only when the Postgres adapter is detected.


### Why LRP?

| System | Paradigm           |
|--------|--------------------|
| SAP    | Transaction driven |
| Odoo   | Module driven      |
| LRP    | **Knowledge driven** |

---

## Current Implementation Status

| Capability | Status | Notes |
|---|---|---|
| 9 Core Tables (Ecto + SQLite3) | ✅ Done | Tenants, Actors, Objects, Items, Relationships, Events, Policies, ProcessTasks, Versions |
| Object CRUD API | ✅ Done | `create_object/1`, `update_object/2`, `create_item/1` |
| Relationship Graph | ✅ Done | `relate/5`, `list_relationships/3`, Semantic path DFS/BFS |
| Multi-channel Event Logging | ✅ Done | Email, Slack, A2A (agent_mesh), thread parent_id |
| Version Snapshots (Full) | ✅ Done | Full snapshot today; JSON Patch delta planned (ADR-0002) |
| Policy-based Authorization (Static) | ✅ Done | `authorize/3` — allow/deny per resource_type+action |
| `actor_confidence` on Events + Versions | ✅ Done | NULL=human, 0.0-1.0=agent; low confidence triggers human review |
| `AgentContext` (Explainability) | ✅ Done | reasoning_trace, model_version, prompt_hash per agent action |
| `AgentCapability` (MCP Tool Registry) | ✅ Done | MCP-compatible tool definitions per actor |
| `idempotency_key` on Events | ✅ Done | Retry-safe; duplicate inserts rejected at DB level |
| `embedding` field on Objects | ✅ Done | Binary field; pgvector(1536) on PostgreSQL via separate migration |
| PostgreSQL RLS | 🔲 Schema ready | SQL in migration, requires PostgreSQL adapter |
| HOT Event Durability | ⚠️ Partial | HOT events are RAM-only today; WAL not yet implemented — **"Everything is traceable" does not apply to HOT tier yet** |
| Ledger (VUK/IFRS) | ✅ Done | Immutable ledgers, journals, lines, and fiscal period locks are implemented & tested |
| Ledger Explainability | ✅ Done | `source_event_id → POSTING_RULE → JOURNAL_LINE` posting automation chain is implemented & tested |
| Capability / Provider / Binding | ✅ Done | Hot-swap active provider bindings (ADR-0004) implemented |
| Migration Tracker | ✅ Done | Stage-based migration tracking (shadow/partial/primary/cutover) (ADR-0005) implemented |
| Onboarding & Observation | ✅ Done | wizard CLI + `ObservationMode` + `MaturityScore` (ADR-0006) implemented |
| Source Connector | ✅ Done | Scans files and Git repos to map code architecture to LRP objects |
| Code Compliance & Codegen | ✅ Done | AST parsers for Elixir/Python and AI-based code modifications/tests |
| Legacy Modernizer MVP | ✅ Done | CLI task (`mix lrp.modernize`) to scan legacy codebases and generate LRP md specs or Elixir code ([Kılavuz](docs/MODERNIZER.md)) |
| ReBAC / OpenFGA | 🔲 Planned | ADR-0003 accepted; static Policy table used for now |
| CQRS Read Views | 🔲 Planned | ADR-0001 accepted; no consumers yet |
| JSON Patch Versioning | 🔲 Planned | ADR-0002 accepted; full snapshot used today |
| Rust/NIF Analytics | 🔲 Phase 3 | Applied after profiling shows BEAM bottleneck; not before |

---

## Architecture

### Core Data Model (9 Tables)

| # | Table | Purpose |
|---|---|---|
| 1 | `TENANT` | Multi-tenancy boundary (PostgreSQL RLS when on Postgres) |
| 2 | `ACTOR` | Identity: User, AI Agent, Webhook, API, Robot |
| 3 | `OBJECT` | Everything: Party, Resource, Document, Folder, Case |
| 4 | `ITEM` | Line items: invoice lines, checklist items, agenda lines |
| 5 | `RELATIONSHIP` | Generic semantic graph edges (ReBAC basis) |
| 6 | `EVENT` | Append-only event stream: Email, Slack, A2A, Webhooks. Tier: **HOT** (RAM-only) \| **DURABLE** (DB). `actor_confidence` + `idempotency_key` fields. |
| 7 | `POLICY` | Static allow/deny rules (ReBAC planned via OpenFGA) |
| 8 | `PROCESS_TASK` | Workflow state machine steps |
| 9 | `VERSION` | Object revision history. `actor_confidence` per commit (NULL=human). |
| 10 | `AGENT_CONTEXT` | Agent decision audit: reasoning_trace, confidence_score, model_version, prompt_hash |
| 11 | `AGENT_CAPABILITY` | MCP-compatible tool registry per agent actor |

### Ledger Layer (Schema Defined, Not Yet Implemented)

Accounting, fiscal periods, and legal ledgers (VUK/IFRS/SPK) are isolated from the
Object Graph in a hard-schema Ledger layer. **This layer is specified but not yet coded.**

```
LEDGER(id, tenant_id, scheme[VUK|IFRS|SPK_CONSOLIDATED], currency, is_leading, status)
ACCOUNT(id, tenant_id, ledger_id, code, name, account_type)
ACCOUNT_MAPPING(id, vuk_account_id, ifrs_account_id, mapping_type)
JOURNAL(id, tenant_id, ledger_id, doc_date, posting_date, reference, source_event_id)
JOURNAL_LINE(id, journal_id, account_id, party_id, debit, credit, currency, is_reversed, vat_code, withholding_code)
FISCAL_PERIOD(id, tenant_id, ledger_id, period_start, period_end, status[open|closed|locked])
POSTING_RULE(id, tenant_id, event_type, ledger_id, debit_account_id, credit_account_id, amount_formula, condition)
LEDGER_SEAL(id, ledger_id, period, gib_beratı_hash, signed_at, xml_storage_key)
```

### Directory Structure (DDD)

```
lrp/
  ├── core/          # Runtime engine & supervisors
  ├── entity/        # Object graph engine
  ├── event/         # Event sourcing, HOT/WARM/COLD, WAL (planned)
  ├── workflow/       # State machines, Oban approval flows
  ├── ledger/        # VUK, IFRS, SPK immutable ledger (planned)
  ├── ai/            # AI Router, classifier (planned)
  ├── agents/        # Process Miner, Compliance Auditor (planned)
  ├── plugins/       # Capability SDK (planned)
  ├── docs/adr/      # Architectural Decision Records
  └── test/          # Integration tests
```

---

## Architectural Decisions (ADRs)

| ADR | Decision | Status |
|---|---|---|
| [ADR-0001](docs/adr/0001-cqrs-read-views.md) | CQRS Read Views (max 5s staleness) | Accepted, not yet implemented |
| [ADR-0002](docs/adr/0002-json-patch-versioning.md) | JSON Patch deltas + 50-patch compaction | Accepted, not yet implemented |
| [ADR-0003](docs/adr/0003-rebac-authorization.md) | ReBAC via OpenFGA | Accepted, not yet implemented |
| [ADR-0004](docs/adr/0004-capability-provider-binding.md) | Capability/Provider/Binding — hot-swap provider pattern | ✅ Implemented |
| [ADR-0005](docs/adr/0005-migration-tracker.md) | MIGRATION_TRACKER — shadow/partial/primary/full_cutover | ✅ Implemented |
| [ADR-0006](docs/adr/0006-observation-mode.md) | OBSERVATION_MODE + MATURITY_SCORE — three onboarding scenarios | ✅ Implemented |
| [ADR-0007](docs/adr/0007-connector-contract.md) | Connector/Adapter contract + EVENT_SUBSCRIPTION outbound | ✅ Implemented |
| [ADR-0008](docs/adr/0008-modular-data-integration-topology.md) | Modular Data Integration Topology & Capability Extensibility | ✅ Implemented |
| [ADR-0009](docs/adr/0009-hybrid-frontend-architecture.md) | Hybrid Frontend Architecture (Phoenix LiveView & Rust/WASM/Perspective) | ✅ Implemented |

---

## Quickstart

### Tek Komutla Kur

```bash
# Repoyu klonla
git clone https://github.com/ilkerkaanipcioglu/LRP.git
cd LRP

# Windows (PowerShell)
./setup.ps1

# Linux / macOS
chmod +x setup.sh && ./setup.sh
```

Setup betiği şunları yapar: Elixir kontrolü → `mix deps.get` → `mix ecto.migrate` → `mix lrp.seed`

---

### İnteraktif Sunum & Canlı Demo Arayüzü

LRP felsefesini, mimari prensiplerini, rakip analizlerini, yevmiye hesaplayıcısını ve geçiş/onboarding simülasyonunu tarayıcıda adım adım görmek için:

```bash
cd demo_ui
npm install
npm run dev
```

Uygulama yerel olarak `http://localhost:5173/` adresinde çalışacaktır.

---

### CLI Komutları

```bash
# Sistem durumu (insan)
mix lrp.status

# Sistem durumu (MCP / AI Agent)
mix lrp.status --json

# Uçtan uca canlı demo (5 dk — yatırımcı/müşteri için)
mix lrp.demo

# Console Kurulum Sihirbazı Demosu (Şirket/Proje)
mix lrp.console

# Tenant yönetimi
mix lrp.tenant list
mix lrp.tenant create --name "Şirket Adı"
mix lrp.tenant create --name "X" --json   # MCP

# Object sorgulama
mix lrp.object list --tenant <id>
mix lrp.object list --tenant <id> --type Document
mix lrp.object get  --id <object_id>
mix lrp.object list --tenant <id> --json  # MCP

# Event akışı
mix lrp.event list --tenant <id>
mix lrp.event list --tenant <id> --limit 50
mix lrp.event list --tenant <id> --json   # MCP

# GitHub repo bağlama (SourceConnector)
mix lrp.connect https://github.com/user/repo

# md-only tasarımları koda yükseltme (Upgrade)
mix lrp.upgrade --from=md-only --to=elixir
mix lrp.upgrade --from=md-only --to=elixir --migrate

# Legacy codebase modernizasyon (Modernize)
mix lrp.modernize --source /path/to/legacy-app --target md
mix lrp.modernize --source /path/to/legacy-app --target elixir --output-dir custom-design
```

---

### Testler

```bash
mix test   # 8 entegrasyon testi
```

The integration tests cover:
- Tenant + Actor creation
- Multi-channel event logging (email, slack, agent-to-agent thread)
- Folder/Case with attachments via Relationship graph
- Two-commit version history (full snapshot)
- Policy-based authorization (allow/deny)
- Semantic graph BFS (`connected?/3`, `get_related_objects/3`)

---

## Roadmap

| Version | Milestone | Status |
|---|---|---|
| v0.1 | Entity Engine (9 core tables + tests) | ✅ Done |
| v0.2 | Workflow Engine (state machines, process tasks) | ✅ Done |
| v0.3 | Ledger (VUK + IFRS Ecto + migrations, posting rules) | ✅ Done |
| v0.4 | Creator Engine & Community Funding (LRP.Creator, LRP.Funding, automated double-entry revenue sharing) | 🚧 In Progress |
| v0.5 | AI Router + Classifier | 🔲 Planned |
| v0.6 | Agent Framework (governance_core integration) | 🔲 Planned |
| v0.7 | Plugin SDK (Registry + validator + LocalStorage plugin) | ✅ Done |
| v1.0 | Production Ready (GİB e-defter, SPK) | 🔲 Planned |
