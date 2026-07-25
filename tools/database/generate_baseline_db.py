#!/usr/bin/env python3

import argparse
import csv
import hashlib
import json
import os
import sqlite3
import tempfile
from pathlib import Path

from action_image_manifest import validate_manifest

BASELINE_MIGRATION_ID = "20260721_0001_baseline"
BASELINE_APPLIED_AT = "2026-07-21T00:00:00Z"
EXPECTED_SEED_COUNTS = {
    "body_part": 10,
    "target_muscle": 19,
    "equipment": 28,
    "action": 272,
    "action_target_muscle_link": 272,
    "template_plans": 2,
    "template_plan_actions": 3,
    "template_plan_sets": 6,
}
MUTABLE_TABLES = (
    "user",
    "training_plans",
    "plan_actions",
    "plan_sets",
    "training_sessions",
    "training_plan_executions",
    "execution_actions",
    "execution_sets",
    "training_history",
    "training_history_details",
    "body_measurements",
    "password_reset_codes",
    "database_version",
)


def parse_args() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(
        description="Generate the clean Stronix SQLite baseline database."
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=script_dir.parents[1]
        / "Stronix-App"
        / "Resources"
        / "Database"
        / "database_stronix.db",
        help="Database path to replace after generation and validation.",
    )
    return parser.parse_args()


def read_lookup_rows(path: Path) -> list[tuple[int, str, str]]:
    with path.open(encoding="utf-8", newline="") as handle:
        rows = [
            (int(row["id"]), row["name"], row["display_name"])
            for row in csv.DictReader(handle)
        ]
    require_sorted_unique(rows, path.name)
    return rows


def read_actions(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as handle:
        actions = json.load(handle)
    ids = [int(action["id"]) for action in actions]
    if ids != sorted(ids) or len(ids) != len(set(ids)):
        raise ValueError(f"{path.name} must contain unique actions sorted by id")
    external_ids = [str(action["external_id"]) for action in actions]
    if len(external_ids) != len(set(external_ids)):
        raise ValueError(f"{path.name} contains duplicate external_id values")
    return actions



def read_template_plans(path: Path, action_ids: set[int]) -> list[dict]:
    with path.open(encoding="utf-8") as handle:
        plans = json.load(handle)

    plan_ids = [int(plan["id"]) for plan in plans]
    if plan_ids != sorted(plan_ids) or len(plan_ids) != len(set(plan_ids)):
        raise ValueError(f"{path.name} must contain unique templates sorted by id")

    external_ids = [str(plan["external_id"]) for plan in plans]
    if len(external_ids) != len(set(external_ids)):
        raise ValueError(f"{path.name} contains duplicate external_id values")

    for plan in plans:
        actions = plan.get("actions", [])
        action_ids_for_plan = [int(action["action_id"]) for action in actions]
        action_orders = [int(action["order"]) for action in actions]
        if not actions or len(action_ids_for_plan) != len(set(action_ids_for_plan)):
            raise ValueError(f"template {plan['id']} must contain unique actions")
        if action_orders != list(range(1, len(actions) + 1)):
            raise ValueError(f"template {plan['id']} actions must use consecutive order values")
        if any(action_id not in action_ids for action_id in action_ids_for_plan):
            raise ValueError(f"template {plan['id']} references an unknown action")

        for action in actions:
            sets = action.get("sets", [])
            set_numbers = [int(item["set_number"]) for item in sets]
            if not sets or set_numbers != list(range(1, len(sets) + 1)):
                raise ValueError(
                    f"template {plan['id']} action {action['action_id']} must use consecutive set numbers"
                )

    return plans


def calculate_action_volume(sets: list[dict], record_bilateral: bool) -> float:
    if record_bilateral:
        return sum(
            (float(item.get("left_weight", 0)) + float(item.get("right_weight", 0)))
            * int(item["reps"])
            for item in sets
        )
    return sum(float(item.get("weight", 0)) * int(item["reps"]) for item in sets)


def insert_template_plans(connection: sqlite3.Connection, plans: list[dict]) -> None:
    for plan in plans:
        connection.execute(
            """
            INSERT INTO template_plans (
                id, external_id, name, description, difficulty, duration, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                int(plan["id"]),
                str(plan["external_id"]),
                plan["name"],
                plan.get("description", ""),
                plan.get("difficulty", ""),
                int(plan.get("duration", 0)),
                BASELINE_APPLIED_AT,
                BASELINE_APPLIED_AT,
            ),
        )
        for action in plan["actions"]:
            sets = action["sets"]
            connection.execute(
                """
                INSERT INTO template_plan_actions (
                    template_plan_id, action_id, "order", sets, rest, weight, note, record_bilateral
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    int(plan["id"]),
                    int(action["action_id"]),
                    int(action["order"]),
                    len(sets),
                    int(action.get("rest", 60)),
                    calculate_action_volume(sets, bool(action.get("record_bilateral"))),
                    action.get("note"),
                    1 if action.get("record_bilateral") else 0,
                ),
            )
            connection.executemany(
                """
                INSERT INTO template_plan_sets (
                    template_plan_id, action_id, set_number, weight, reps, created_at,
                    left_weight, right_weight, notes
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        int(plan["id"]),
                        int(action["action_id"]),
                        int(item["set_number"]),
                        float(item.get("weight", 0)),
                        int(item["reps"]),
                        BASELINE_APPLIED_AT,
                        float(item.get("left_weight", 0)),
                        float(item.get("right_weight", 0)),
                        item.get("notes"),
                    )
                    for item in sets
                ],
            )


def require_sorted_unique(rows: list[tuple[int, str, str]], source_name: str) -> None:
    ids = [row[0] for row in rows]
    if ids != sorted(ids) or len(ids) != len(set(ids)):
        raise ValueError(f"{source_name} must contain unique rows sorted by id")


def insert_lookup_rows(
    connection: sqlite3.Connection,
    table: str,
    rows: list[tuple[int, str, str]],
) -> None:
    connection.executemany(
        f"INSERT INTO {table} (id, name, display_name) VALUES (?, ?, ?)",
        rows,
    )


def insert_actions(connection: sqlite3.Connection, actions: list[dict]) -> None:
    connection.executemany(
        """
        INSERT INTO action (
            id, external_id, name, name_en, "gifUrl", description,
            description_en, difficulty, bodypart_id, equipment_id, is_bilateral
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                int(action["id"]),
                str(action["external_id"]),
                action["name"],
                action.get("name_en"),
                action.get("gifUrl"),
                action.get("description"),
                action.get("description_en"),
                action.get("difficulty"),
                int(action["bodypart_id"]),
                int(action["equipment_id"])
                if action.get("equipment_id") is not None
                else None,
                1 if action.get("is_bilateral") else 0,
            )
            for action in actions
        ],
    )

    links = [
        (int(action["id"]), int(target_muscle_id))
        for action in actions
        for target_muscle_id in sorted(action["target_muscle_ids"])
    ]
    if len(links) != len(set(links)):
        raise ValueError("actions.json contains duplicate action/target-muscle links")
    connection.executemany(
        """
        INSERT INTO action_target_muscle_link (action_id, target_muscle_id)
        VALUES (?, ?)
        """,
        links,
    )


def validate_database(connection: sqlite3.Connection) -> None:
    integrity_rows = [row[0] for row in connection.execute("PRAGMA integrity_check")]
    if integrity_rows != ["ok"]:
        raise ValueError(f"integrity_check failed: {integrity_rows}")

    foreign_key_rows = list(connection.execute("PRAGMA foreign_key_check"))
    if foreign_key_rows:
        raise ValueError(f"foreign_key_check failed: {foreign_key_rows}")

    for table, expected_count in EXPECTED_SEED_COUNTS.items():
        actual_count = connection.execute(
            f"SELECT COUNT(*) FROM {table}"
        ).fetchone()[0]
        if actual_count != expected_count:
            raise ValueError(
                f"Unexpected {table} count: {actual_count}, expected {expected_count}"
            )

    for table in MUTABLE_TABLES:
        actual_count = connection.execute(
            f"SELECT COUNT(*) FROM {table}"
        ).fetchone()[0]
        if actual_count != 0:
            raise ValueError(f"Mutable table {table} is not empty: {actual_count}")

    ledger_rows = list(
        connection.execute(
            "SELECT migration_id, applied_at FROM schema_migrations ORDER BY migration_id"
        )
    )
    expected_ledger = [(BASELINE_MIGRATION_ID, BASELINE_APPLIED_AT)]
    if ledger_rows != expected_ledger:
        raise ValueError(f"Unexpected schema ledger: {ledger_rows}")

    trigger_rows = [
        row[0]
        for row in connection.execute(
            """
            SELECT name
            FROM sqlite_schema
            WHERE type = 'trigger' AND tbl_name = 'schema_migrations'
            ORDER BY name
            """
        )
    ]
    expected_triggers = [
        "schema_migrations_prevent_delete",
        "schema_migrations_prevent_update",
    ]
    if trigger_rows != expected_triggers:
        raise ValueError(f"Unexpected schema ledger triggers: {trigger_rows}")


def logical_fingerprint(connection: sqlite3.Connection) -> str:
    digest = hashlib.sha256()
    schema_rows = connection.execute(
        """
        SELECT type, name, tbl_name, sql
        FROM sqlite_schema
        WHERE name NOT LIKE 'sqlite_%'
        ORDER BY type, name
        """
    )
    for row in schema_rows:
        digest.update(json.dumps(row, ensure_ascii=False).encode("utf-8"))

    for table in (
        "schema_migrations",
        "body_part",
        "target_muscle",
        "equipment",
        "action",
        "action_target_muscle_link",
        "template_plans",
        "template_plan_actions",
        "template_plan_sets",
    ):
        for row in connection.execute(f"SELECT * FROM {table} ORDER BY 1, 2"):
            digest.update(json.dumps(row, ensure_ascii=False).encode("utf-8"))
    return digest.hexdigest()


def generate(output: Path) -> str:
    script_dir = Path(__file__).resolve().parent
    schema_path = script_dir / "schema" / "baseline.sql"
    seed_dir = script_dir / "seeds"

    body_parts = read_lookup_rows(seed_dir / "body_parts.csv")
    target_muscles = read_lookup_rows(seed_dir / "target_muscles.csv")
    equipment = read_lookup_rows(seed_dir / "equipment.csv")
    actions = read_actions(seed_dir / "actions.json")
    _, image_diagnostics = validate_manifest(
        actions,
        seed_dir / "action_images.json",
        script_dir.parents[1] / "Stronix-App" / "Resources",
    )
    if image_diagnostics:
        raise ValueError("\n".join(diagnostic.format() for diagnostic in image_diagnostics))
    template_plans = read_template_plans(
        seed_dir / "template_plans.json",
        {int(action["id"]) for action in actions},
    )

    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    file_descriptor, temporary_path = tempfile.mkstemp(
        prefix=f".{output.name}.",
        suffix=".tmp",
        dir=output.parent,
    )
    os.close(file_descriptor)
    temporary_output = Path(temporary_path)

    try:
        connection = sqlite3.connect(temporary_output)
        try:
            connection.execute("PRAGMA foreign_keys = ON")
            connection.executescript(schema_path.read_text(encoding="utf-8"))
            with connection:
                insert_lookup_rows(connection, "body_part", body_parts)
                insert_lookup_rows(connection, "target_muscle", target_muscles)
                insert_lookup_rows(connection, "equipment", equipment)
                insert_actions(connection, actions)
                insert_template_plans(connection, template_plans)
                connection.execute(
                    "INSERT INTO schema_migrations (migration_id, applied_at) VALUES (?, ?)",
                    (BASELINE_MIGRATION_ID, BASELINE_APPLIED_AT),
                )
            connection.execute("VACUUM")
            validate_database(connection)
            fingerprint = logical_fingerprint(connection)
        finally:
            connection.close()
        os.replace(temporary_output, output)
        return fingerprint
    except Exception:
        temporary_output.unlink(missing_ok=True)
        raise


def main() -> None:
    args = parse_args()
    fingerprint = generate(args.output)
    print(f"Generated {args.output.resolve()}")
    print(f"Logical fingerprint: {fingerprint}")


if __name__ == "__main__":
    main()
