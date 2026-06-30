# LRP Agents Agreement

This document binds all autonomous AI coding agents and human developers working in the LRP repository.

## Core Rules & Contracts

1.  **AI-native Enterprise OS Vision:**
    LRP is not a modular ERP. It is a Knowledge Graph Operating System. Every feature, database query, or API design must treat everything as an Entity or an Event.
2.  **No Direct UPDATE or DELETE (Event Sourcing):**
    Never write code that directly updates or deletes entity data fields in production tables (except metadata / versioning control tables). Changes must be modeled as append-only `EVENT` records. Dynamic current states must be computed via **Projections**.
3.  **Strict CQRS Isolation:**
    Never run complex analytical or reporting queries directly against the `OBJECT` or `RELATIONSHIP` write tables. All reporting must use the materialized read models (Read Views), accepting a maximum latency of 5 seconds.
4.  **Database Level Security (RLS):**
    All Ecto queries must carry and enforce the `tenant_id` context. When working with PostgreSQL, Row-Level Security (RLS) policies must be respected and active.
5.  **JSON Patch (RFC 6902) Versioning:**
    Version control for objects must store deltas/diffs using JSON Patch arrays. Compaction (squashing into a full snapshot) must be triggered automatically every **50 patches**.
6.  **ReBAC (Relation-based Access Control):**
    Authorization checks must be resolved dynamically by traversing the relations in the `RELATIONSHIP` graph, aligned with OpenFGA patterns.

## Codebase Organization (DDD)

Adhere strictly to the Domain-Driven Design directory structure:
- `/core` -> Runtime & supervisor lifecycle.
- `/entity` -> Entity engine, objects, items, relationships.
- `/event` -> Events, Event Sourcing, projections, WAL.
- `/ledger` -> Hard-schema ledger engine (VUK, IFRS, seals, mappings).
- `/ai` -> AI Router, classifiers.
- `/agents` -> Process Mining, compliance auditors.
