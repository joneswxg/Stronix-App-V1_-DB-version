# Stronix baseline database

The files in this directory are the source of truth for the bundled local SQLite database.

- `schema/baseline.sql` defines the clean baseline schema.
- `seeds/body_parts.csv`, `target_muscles.csv`, and `equipment.csv` contain flat static catalogs.
- `seeds/actions.json` contains actions and their target-muscle relationships.
- `seeds/template_plans.json` contains the built-in Template Plan catalog, ordered actions, and ordered sets.
- `generate_baseline_db.py` builds and validates the checked-in database artifact.

Generate the bundle database from the repository root:

```bash
python3 tools/database/generate_baseline_db.py \
  --output Stronix-App/Resources/Database/database_stronix.db
```

The generator creates a fresh temporary database, imports all seed rows in deterministic ID order, inserts the immutable `20260721_0001_baseline` ledger record, verifies the append-only ledger triggers, runs integrity and foreign-key checks, then atomically replaces the output. Future migrations may only append records to `schema_migrations`; changing or deleting a completed record is rejected by the database.

Expected static catalog counts:

| Table | Rows |
| --- | ---: |
| `body_part` | 10 |
| `target_muscle` | 19 |
| `equipment` | 28 |
| `action` | 272 |
| `action_target_muscle_link` | 272 |
| `template_plans` | 2 |
| `template_plan_actions` | 3 |
| `template_plan_sets` | 6 |

All mutable business tables start empty. Template Plans are deterministic product catalog data and are seeded from `template_plans.json`; they never carry user ownership. Seed IDs and action `external_id` values are stable product identifiers; do not renumber them. The previous bundled database is not an input to generation. Any future product catalog change must edit these reviewable seed files and regenerate the artifact.
