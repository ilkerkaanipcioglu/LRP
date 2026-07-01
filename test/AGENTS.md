# DOX framework — test/

- Parent: [LRP root AGENTS.md](../AGENTS.md)
- Scope: All test files under `test/`

## Local Contract

Tests are the primary correctness signal for LRP. Every schema contract and public API function must be exercised by at least one test. Tests run against SQLite3 in `:test` env — do not assume PostgreSQL-specific features (RLS, pgvector) in automated tests.

## Test File Index

| File | Coverage |
|---|---|
| `lrp_test.exs` | Full Object Graph integration: Tenant, Actor, Object, Item, Relationship, Event, Policy, ProcessTask, Version, AgentContext, AgentCapability |
| `lrp_inbox_test.exs` | Broadway inbox pipeline — event ingestion |
| `lrp_source_connector_test.exs` | GitHub repo → LRP Object Graph import (uses mock/bypass for HTTP) |
| `test_helper.exs` | ExUnit config, Ecto sandbox setup |

## Testing Rules

1. **One test file per functional area.** Do not mix schema tests with connector tests.
2. **Use `Ecto.Adapters.SQL.Sandbox`** for all database tests. No direct DB state shared between test cases.
3. **No live HTTP calls in tests.** `LRP.SourceConnector` tests must use Bypass or a pre-recorded fixture for GitHub API responses.
4. **Test naming convention**: `test "verb phrase that describes behavior"` — not `test "function_name"`.
5. **Assert on return values and side effects.** Do not just assert `{:ok, _}` — verify the returned struct fields match expectations.
6. **When adding a new module** to `lib/lrp/`, add a corresponding test block (or new test file) and update the Test File Index above.

## Running Tests

```bash
mix test                    # all tests
mix test test/lrp_test.exs  # specific file
mix test --trace            # verbose output
```

- 🔴 **Software Engineering Principles**: Geliştirmeye başlamadan önce mutlaka [ENTERPRISE-ENGINEERING-PRINCIPLES.md](file:///B:/DEV/ENTERPRISE-ENGINEERING-PRINCIPLES.md) dosyasını okuyun, projenin tier seviyesini belirleyin ve kurallara uyun. Eğer bu kurallar dışında bir uygulama yapılacaksa bu durum `AGENTS.md` dosyasında belirtilmelidir; gerekirse `ENTERPRISE-ENGINEERING-PRINCIPLES.md` dosyası proje klasörüne kopyalanıp özelleştirilmiş bir versiyonu oluşturulabilir. Değişiklik küçükse sadece `AGENTS.md` dosyasında belirtilmesi yeterlidir.
