# LRP — AI-native Enterprise Operating System

> For the full vision and where LRP is going, see **[VISION.md](VISION.md)**.
>
> This document describes **current implementation status** — what is actually built and what is not yet.

---

## What LRP Is (Today)

LRP (Lightweight Resource Planning) is an Elixir/SQLite3 based **Object Graph Engine** —
a generic, event-driven core that eliminates domain-specific tables and replaces them with
9 universal tables. It is designed to be the foundation on which AI-native enterprise
applications are built.

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
| Relationship Graph | ✅ Done | `relate/5`, `list_relationships/3` |
| Multi-channel Event Logging | ✅ Done | Email, Slack, A2A (agent_mesh), thread parent_id |
| Version Snapshots (Full) | ✅ Done | Full snapshot today; JSON Patch delta planned (ADR-0002) |
| Policy-based Authorization (Static) | ✅ Done | `authorize/3` — allow/deny per resource_type+action |
| PostgreSQL RLS | 🔲 Schema ready | SQL in migration, requires PostgreSQL adapter |
| HOT Event Durability | ⚠️ Partial | HOT events are RAM-only today; WAL/ring-buffer not yet implemented — **"Everything is traceable" does not apply to HOT tier yet** |
| Ledger (VUK/IFRS) | 🔲 Planned | Schema defined in README; no Ecto schemas or migrations yet |
| Ledger Explainability | 🔲 Planned | `source_event_id → POSTING_RULE → JOURNAL_LINE` audit chain not yet built — **"Everything is explainable" applies to Object Graph only today** |
| ReBAC / OpenFGA | 🔲 Planned | ADR-0003 accepted; static Policy table used for now |
| CQRS Read Views | 🔲 Planned | ADR-0001 accepted; no consumer/projection workers yet |
| JSON Patch Versioning | 🔲 Planned | ADR-0002 accepted; full snapshot used today |

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
| 6 | `EVENT` | Append-only event stream: Email, Slack, A2A, Webhooks |
| 7 | `POLICY` | Static allow/deny rules (ReBAC planned via OpenFGA) |
| 8 | `PROCESS_TASK` | Workflow state machine steps |
| 9 | `VERSION` | Object revision history (full snapshot today, JSON Patch planned) |

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

---

## Quickstart (PoC)

```bash
git clone https://github.com/ilkerkaanipcioglu/LRP.git
cd LRP
mix deps.get
mix test
```

The integration test covers the full Object Graph flow:
- Tenant + Actor creation
- Multi-channel event logging (email, slack, agent-to-agent thread)
- Folder/Case with attachments via Relationship graph
- Two-commit version history (full snapshot)
- Policy-based authorization (allow/deny)

---

## Roadmap

| Version | Milestone | Status |
|---|---|---|
| v0.1 | Entity Engine (9 core tables + tests) | ✅ Done |
| v0.2 | Workflow Engine (state machines) | 🔲 Planned |
| v0.3 | Ledger (VUK + IFRS Ecto + migrations) | 🔲 Planned |
| v0.4 | AI Router + Classifier | 🔲 Planned |
| v0.5 | Agent Framework (governance_core integration) | 🔲 Planned |
| v0.6 | Plugin SDK | 🔲 Planned |
| v1.0 | Production Ready (GİB e-defter, SPK) | 🔲 Planned |
