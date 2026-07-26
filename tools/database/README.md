# Stronix baseline database

The files in this directory are the source of truth for the bundled local SQLite database.

- `schema/baseline.sql` defines the clean baseline schema.
- `seeds/body_parts.csv`, `target_muscles.csv`, and `equipment.csv` contain flat static catalogs.
- `seeds/actions.json` contains actions and their target-muscle relationships.
- `seeds/action_images.json` is the auditable source of action-to-GIF mappings.
- `seeds/template_plans.json` contains the built-in Template Plan catalog, ordered actions, and ordered sets.
- `generate_baseline_db.py` builds and validates the checked-in database artifact.

## Intentional bundle publishing

Generate the bundle database from the repository root only when intentionally updating the checked-in artifact:

```bash
python3 tools/database/validate_action_images.py
python3 tools/database/generate_baseline_db.py \
  --output Stronix-App/Resources/Database/database_stronix.db
```

The generator creates a fresh temporary database, imports all seed rows in deterministic ID order, inserts the immutable `20260721_0001_baseline` source-baseline ledger record, verifies the append-only ledger triggers, runs integrity and foreign-key checks, then atomically replaces the specified output. Future migrations apply after this source baseline is copied to the mutable Documents database; the source baseline never represents a runtime-prepared Documents database.

## Non-mutating bundled-baseline verification

Verify the tracked bundle without replacing it:

```bash
python3 tools/database/generate_baseline_db.py --verify-bundled-baseline
```

Verification generates a candidate only in temporary storage, opens `Stronix-App/Resources/Database/database_stronix.db` read-only, validates both databases against the source-baseline contract, and compares logical fingerprints. It does not compare SQLite file bytes, write beside the tracked bundle, or access a user's Documents database. Use `--bundle <path>` only to verify an explicit alternate bundle read-only.

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
