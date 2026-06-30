# LRP — Vision

> **"An AI-native Enterprise Operating System where every business object is an entity,
> every change is an event, every workflow is explainable,
> and every decision can be delegated to humans or AI agents."**

---

## Where We're Going

```
ERP is not software.
ERP is a knowledge graph.

Everything is an entity.
Everything is an event.
Everything is traceable.
Everything is explainable.
```

### Why LRP?

| System | Paradigm       |
|--------|----------------|
| SAP    | Transaction driven |
| Odoo   | Module driven  |
| LRP    | **Knowledge driven** |

---

## The Full Vision

### 1. Everything is an Entity
Every business concept — Customer, Vendor, Contract, Document, AI Agent, Invoice — is a
generic `OBJECT`. Roles (Customer, Vendor, Employee) are added dynamically. No separate
tables per module. The schema never changes; the knowledge graph grows.

### 2. Everything is an Event (Event Sourcing)
There are no `UPDATE` or `DELETE` commands in LRP. Every state change emits an append-only event:
```
EntityCreated / EntityChanged / StockMoved / InvoicePosted / PaymentReceived
```
Current state (Current Stock, Current Balance) is always derived from projections over the
event stream — never from a mutable row.

### 3. Everything is Traceable (Full Audit)
When fully realized, every HOT/WARM/COLD event is durably committed before acknowledgment.
Every JOURNAL_LINE links back to `source_event_id` → `POSTING_RULE` → triggering `EVENT`,
creating a single unbroken audit chain from business event to ledger entry across all
GAAP schemes (VUK, IFRS, SPK).

### 4. Everything is Explainable (AI + Ledger)
When an AI agent makes a recommendation or a ledger entry is questioned, the system must
answer *why*:
```
Invoice amount = X
Because: Posting Rule #42 applied to event "InvoiceApproved"
Source event payload: { supplier_score: 0.8, delivery_delay: 2d }
Ledger: VUK | Account: 320 → 100
```
Explainability spans both the Object Graph (AI reasoning trace) and the Ledger
(posting rule + event provenance).

### 5. AI as Runtime, Not Feature
AI is not an assistant tab. It runs inline at every operation:
```
entity.create() → AI Validation → Duplicate Detection → Risk Scoring → Workflow Suggestion → Save
```

### 6. Agent Router at the Core
```
Request → Classifier → Cheap Model → Reasoning Model → Local LLM → External LLM
```

---

## Implementation Stages

| Version | Milestone             | Status      |
|---------|-----------------------|-------------|
| v0.1    | Entity Engine         | ✅ Done     |
| v0.2    | Workflow Engine       | 🔲 Planned  |
| v0.3    | Ledger (VUK + IFRS)  | 🔲 Planned  |
| v0.4    | AI Router             | 🔲 Planned  |
| v0.5    | Agent Framework       | 🔲 Planned  |
| v0.6    | Plugin SDK            | 🔲 Planned  |
| v1.0    | Production Ready      | 🔲 Planned  |

---

> This is a vision document — it describes where LRP is going, not where it is today.
> For current capabilities and honest implementation status, see [README.md](README.md).
