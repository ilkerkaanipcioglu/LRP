# LRP Legacy Modernizer — User Guide & Architecture Documentation

Welcome to the **LRP Legacy Modernizer MVP**! This tool is designed to scan legacy software codebases (local folders or GitHub repositories) and assist in modernizing them into the LRP standard architecture.

It has two output modes:
1. **Design Mode (`--target md`)**: Discovers legacy entities/schemas and maps them to LRP Capabilities, Providers, and a global README containing the **8-point LRP Migration Checklist (FİKİRLER)**.
2. **Code Mode (`--target elixir`)**: Generates both the `.md` design files and automatically scaffolds compliant Elixir code (Migrations, Ecto Schemas, Contexts).

---

## Quickstart Commands

### 1. Generate LRP Architectural Markdown Design (.md)
To analyze a legacy folder and generate structured design specifications (README, Capabilities, Providers):
```bash
mix lrp.modernize --source /path/to/legacy-app --target md --output-dir docs/my-lrp-design
```

### 2. Generate Design + Scaffold Elixir Code
To analyze a legacy folder, generate the markdown specifications, and immediately scaffold compliant Elixir migration, schema, and context files:
```bash
mix lrp.modernize --source /path/to/legacy-app --target elixir
```

### 3. Scan a Private GitHub Repository
You can pass a GitHub Personal Access Token (PAT) to analyze private repositories directly from GitHub:
```bash
mix lrp.modernize --source https://github.com/owner/private-repo --token your_github_pat_here
```

---

## How It Works Under the Hood

```
[Legacy Source] ──► [Entity Discovery] ──► [Capability Mapper] ──► [MdOnly Output]
                                                                        │
                                                                   (target: elixir)
                                                                        ▼
                                                              [Elixir Code Scaffolder]
```

### 1. Entity Discovery
The modernizer scans file paths and contents recursively to find database tables and entities. It looks for typical pattern names:
* **Ruby on Rails**: `db/migrate/*.rb`, `app/models/*.rb`
* **Prisma (TypeScript/Node)**: `prisma/schema.prisma`
* **Elixir/Phoenix**: `priv/repo/migrations/*.exs`, `lib/**/*.ex`
* **Python**: `db.py`, `models.py`, `database.py`, `schema.py`
* **Generic SQL**: `schema.sql`, `database.sql`

It parses table/model names using regular expressions (e.g. `CREATE TABLE leads`, `model Order`, `class User`).

### 2. Capability Mapping
Each discovered entity (e.g., `Order`) is translated into:
- A singular LRP **Capability** (e.g., `order`) with interface contracts (`create/1`, `get/1`, `list/1`, `search/2`).
- An active **Provider** specifying the technology stack (e.g., `order-elixir_module.md` representing the native implementation).

---

## Generated Folder Structure

The generated output directory contains the following:

```
docs/lrp-design/
├── README.md                      # Overview of system & LRP Migration Checklist
├── capabilities/
│   ├── leads.md                   # Capability specification for 'leads'
│   └── offers.md                  # Capability specification for 'offers'
└── providers/
    ├── leads-elixir_module.md     # Native Elixir provider details for 'leads'
    └── offers-elixir_module.md    # Native Elixir provider details for 'offers'
```

---

## LRP Migration Checklist (FİKİRLER)

Every generated `README.md` file contains the **8-point LRP Migration Checklist (FİKİRLER)** to guide you through manual review:

1. **Core Independence**: Check if the module directly references external vendors/technologies (like Stripe, Gmail, Slack). If yes, abstract them into the **Provider** layer, keeping the **Core Capability** generic.
2. **Event Sourcing**: Verify if there are direct `UPDATE` or `DELETE` statements on business records. If yes, convert them to append-only **EVENTS** to ensure an immutable audit log.
3. **Auditability**: Ensure all records log *who* did it, *when*, and *why* (via `reasoning_trace` and `confidence_score` if performed by an AI Agent).
4. **API-First**: Check if the code is directly coupled to UI controls. Abstract it into clean API context contracts first.
5. **Idempotency**: Verify that executing the same action twice (due to network retries) does not create duplicate entries. Implement `idempotency_key` checking.
6. **Performance Budget**: Define clear response budgets (e.g. `< 200ms`) and monitor them.
7. **AI-Native Routing**: For decisions made by agents, routing should check confidence levels and route to humans for approvals if confidence is low.
8. **Future-Proofing**: Remove hardcoded constraints (like assuming a single currency or a single authentication method) and abstract them via pluggable provider bindings.

---

## Next Steps After Generation

### If you generated Markdown (`--target md`)
1. Open and review `docs/lrp-design/README.md`.
2. Inspect the generated capabilities in the `capabilities/` folder and adjust the function contracts if necessary.
3. When you are ready to generate Elixir code, run the Upgrade command:
   ```bash
   mix lrp.upgrade --from=md-only --to=elixir --dir docs/lrp-design
   ```

### If you generated Elixir (`--target elixir`)
1. Review the generated Ecto migration files in `priv/repo/migrations/`.
2. Apply the migrations to your database:
   ```bash
   mix ecto.migrate
   ```
3. Implement the business logic for the dynamic functions in the generated context modules under `lib/lrp/`.
