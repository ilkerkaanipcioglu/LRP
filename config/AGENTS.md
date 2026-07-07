# DOX framework — config/

- Parent: [LRP root AGENTS.md](../AGENTS.md)
- Scope: All configuration files under `config/`

## Local Contract

This directory holds Mix runtime configuration. Configuration is **environment-specific** and must never contain secrets in source control.

## Config File Index

| File | Environment | Purpose |
|---|---|---|
| `config.exs` | All | Base config: logger, runtime_tools, Endpoint + PubSub + LiveView signing salt |
| `dev.exs` | `:dev` | SQLite3 dev database path; HTTP port 4000, debug_errors, code_reloader, live_reload |
| `test.exs` | `:test` | SQLite3 in-memory or temp DB for tests; Ecto sandbox pool; HTTP port 4002, server: false |
| `runtime.exs` | `:prod` | Production SECRET_KEY_BASE + DATABASE_URL from environment variables |

## Editing Rules

1. **No secrets in config files.** API tokens, database passwords, and credentials must be injected via environment variables using `System.get_env/2` in `runtime.exs` (create if needed).
2. **PostgreSQL config** (for production) must be added in a `runtime.exs` file, not in `config.exs`. Use `DATABASE_URL` env var pattern.
3. **Ecto pool**: Use `Ecto.Adapters.SQL.Sandbox` pool only in `test.exs`. Never in `dev.exs` or `config.exs`.
4. **Adding a new dependency** with config requirements: add its configuration block to the appropriate env file and document it here.

## Database Strategy

| Environment | Adapter | Pool |
|---|---|---|
| `:dev` | `Ecto.Adapters.SQLite3` | Default |
| `:test` | `Ecto.Adapters.SQLite3` | `Ecto.Adapters.SQL.Sandbox` |
| `:prod` | `Ecto.Adapters.Postgres` | Default (set via `DATABASE_URL`) |

> PostgreSQL RLS policies in `priv/repo/migrations/` are conditional on adapter detection. They are ignored by SQLite3.

- 🔴 **Software Engineering Principles**: Geliştirmeye başlamadan önce mutlaka [ENTERPRISE-ENGINEERING-PRINCIPLES.md](file:///B:/DEV/ENTERPRISE-ENGINEERING-PRINCIPLES.md) dosyasını okuyun, projenin tier seviyesini belirleyin ve kurallara uyun. Eğer bu kurallar dışında bir uygulama yapılacaksa bu durum `AGENTS.md` dosyasında belirtilmelidir; gerekirse `ENTERPRISE-ENGINEERING-PRINCIPLES.md` dosyası proje klasörüne kopyalanıp özelleştirilmiş bir versiyonu oluşturulabilir. Değişiklik küçükse sadece `AGENTS.md` dosyasında belirtilmesi yeterlidir.
