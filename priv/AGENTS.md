# DOX framework — priv/

- Parent: [LRP root AGENTS.md](../../AGENTS.md)
- Scope: All files under `priv/` — database files and migrations

## Local Contract

This directory contains Ecto migrations and the SQLite3 dev/test database files. Migrations are **immutable** once run against any persistent database. A new migration must be created to alter or fix an existing schema.

## Migration Index

| File | Migration | Applied Tables |
|---|---|---|
| `repo/migrations/20260630000000_create_lrp_object_graph.exs` | Initial schema | `tenants`, `actors`, `objects`, `items`, `relationships`, `events`, `policies`, `process_tasks`, `versions` |
| `repo/migrations/20260630000001_create_agent_context.exs` | Agent explainability | `agent_contexts` |
| `repo/migrations/20260630000002_create_agent_capabilities.exs` | MCP tool registry | `agent_capabilities` |
| `repo/migrations/20260630000003_add_actor_confidence_and_idempotency.exs` | Agent trust signals | `events.actor_confidence`, `events.idempotency_key`, `versions.actor_confidence` |
| `repo/migrations/20260630000004_add_embedding_to_objects.exs` | Vector search | `objects.embedding` (binary; pgvector on PostgreSQL) |

## Migration Rules

1. **Never modify an existing migration file.** If an applied migration needs a fix, create a new migration.
2. **Migration naming**: `YYYYMMDDHHMMSS_snake_case_description.exs` — use the current UTC timestamp.
3. **Rollback parity**: Every `up` block must have a corresponding `down` block unless the change is truly irreversible (document why with a comment).
4. **PostgreSQL RLS**: `CREATE POLICY` statements in migrations are conditional — guard them with a `case repo().adapter()` check so they are no-ops on SQLite3.
5. **Schema additions must sync**: When adding a migration, also add the field to the corresponding Ecto schema in `lib/lrp/schemas.ex` and update the Module Index in `lib/lrp/AGENTS.md`.
6. **After adding a migration**, add its entry to the Migration Index table above.

## Database Files (Not Committed)

`priv/repo/lrp_test.db`, `*.db-shm`, `*.db-wal` — these are SQLite3 test database files. They are listed in `.gitignore` and must not be committed.

## Running Migrations

```bash
mix ecto.create    # create the database
mix ecto.migrate   # run all pending migrations
mix ecto.rollback  # roll back the last migration
```

- 🔴 **Software Engineering Principles**: Geliştirmeye başlamadan önce mutlaka [ENTERPRISE-ENGINEERING-PRINCIPLES.md](file:///B:/DEV/ENTERPRISE-ENGINEERING-PRINCIPLES.md) dosyasını okuyun, projenin tier seviyesini belirleyin ve kurallara uyun. Eğer bu kurallar dışında bir uygulama yapılacaksa bu durum `AGENTS.md` dosyasında belirtilmelidir; gerekirse `ENTERPRISE-ENGINEERING-PRINCIPLES.md` dosyası proje klasörüne kopyalanıp özelleştirilmiş bir versiyonu oluşturulabilir. Değişiklik küçükse sadece `AGENTS.md` dosyasında belirtilmesi yeterlidir.
