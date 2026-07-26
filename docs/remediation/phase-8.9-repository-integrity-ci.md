# Phase 8.9: Repository Integrity CI

## Purpose

Pull requests and pushes to `main` run **Repository integrity checks** before simulator failures are attributed to unrelated repository maintenance defects. This job runs on `ubuntu-latest` with Git, Python, and SQLite only; it has no Xcode, simulator, or `DatabaseLifecycle` dependency.

## Independently diagnosable checks

The workflow reports one check result for each command:

```bash
sh tools/check_tracked_noise.sh
python3 tools/verify_file_permissions.py
python3 tools/database/validate_action_images.py
python3 -m unittest tools.database.tests.test_action_image_manifest
python3 tools/database/generate_baseline_db.py --verify-bundled-baseline
python3 tools/verify_repository_integrity_ci.py
```

The final command verifies that this job retains its Linux runner, independent named checks, and documentation contract.

## Bundled SQLite contract

`--verify-bundled-baseline` generates a candidate database only under temporary storage. It opens the checked-in `Stronix-App/Resources/Database/database_stronix.db` read-only, validates both source baselines, and compares their logical fingerprints rather than SQLite bytes or page layout.

The bundled baseline deliberately records `20260721_0001_baseline` only. It is copied before runtime migrations append later ledger entries in the mutable Documents database. This CI check never creates, opens, or accesses a user's Documents database.

## Diagnostics and artifacts

Each command emits structural failures at its own seam: tracked paths, Git-index modes, manifest mapping diagnostics, baseline validation failures, or mismatched logical fingerprints. The job intentionally uploads no artifacts. Generated databases, resource dumps, and raw logs remain unavailable outside the temporary runner filesystem.
