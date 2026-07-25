from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any

MANIFEST_SCHEMA_VERSION = 1
_REQUIRED_KEYS = {"action_id", "external_id", "resource_path"}


@dataclass(frozen=True)
class Diagnostic:
    code: str
    message: str
    action_id: int | None = None
    external_id: str | None = None
    resource_path: str | None = None

    def format(self) -> str:
        fields = []
        if self.action_id is not None:
            fields.append(f"action_id={self.action_id}")
        if self.external_id is not None:
            fields.append(f"external_id={self.external_id}")
        if self.resource_path is not None:
            fields.append(f"resource_path={self.resource_path}")
        context = f" {' '.join(fields)}" if fields else ""
        return f"ERROR [{self.code}]{context}: {self.message}"


def _sort_key(diagnostic: Diagnostic) -> tuple[str, int, str, str, str]:
    return (
        diagnostic.code,
        diagnostic.action_id if diagnostic.action_id is not None else -1,
        diagnostic.external_id or "",
        diagnostic.resource_path or "",
        diagnostic.message,
    )


def _is_valid_resource_path(resource_path: Any) -> bool:
    if not isinstance(resource_path, str) or not resource_path:
        return False
    path = PurePosixPath(resource_path)
    return (
        "\\" not in resource_path
        and not path.is_absolute()
        and path.parts[:1] == ("Images",)
        and all(part not in (".", "..") for part in path.parts)
        and resource_path.endswith(".gif")
    )


def _read_manifest(path: Path) -> tuple[Any | None, list[Diagnostic]]:
    try:
        with path.open(encoding="utf-8") as handle:
            return json.load(handle), []
    except OSError as error:
        return None, [Diagnostic("manifest.unreadable", str(error))]
    except json.JSONDecodeError as error:
        return None, [Diagnostic("manifest.invalid-json", str(error))]


def validate_manifest(
    actions: list[dict[str, Any]], manifest_path: Path, resources_root: Path
) -> tuple[list[dict[str, Any]], list[Diagnostic]]:
    manifest, diagnostics = _read_manifest(manifest_path)
    if not isinstance(manifest, dict):
        if manifest is not None:
            diagnostics.append(Diagnostic("manifest.invalid-root", "root must be an object"))
        return [], sorted(diagnostics, key=_sort_key)

    if manifest.get("schema_version") != MANIFEST_SCHEMA_VERSION:
        diagnostics.append(
            Diagnostic(
                "manifest.unsupported-schema-version",
                f"schema_version must be {MANIFEST_SCHEMA_VERSION}",
            )
        )

    mappings = manifest.get("mappings")
    if not isinstance(mappings, list):
        diagnostics.append(Diagnostic("manifest.invalid-mappings", "mappings must be an array"))
        return [], sorted(diagnostics, key=_sort_key)

    valid_mappings: list[dict[str, Any]] = []
    for index, mapping in enumerate(mappings):
        if not isinstance(mapping, dict):
            diagnostics.append(Diagnostic("manifest.malformed-mapping", f"mapping at index {index} must be an object"))
            continue

        action_id = mapping.get("action_id")
        external_id = mapping.get("external_id")
        resource_path = mapping.get("resource_path")
        if set(mapping) != _REQUIRED_KEYS:
            diagnostics.append(
                Diagnostic(
                    "manifest.malformed-mapping",
                    "mapping must contain only action_id, external_id, and resource_path",
                    action_id if isinstance(action_id, int) else None,
                    external_id if isinstance(external_id, str) else None,
                    resource_path if isinstance(resource_path, str) else None,
                )
            )
            continue
        if not isinstance(action_id, int) or isinstance(action_id, bool) or action_id <= 0:
            diagnostics.append(Diagnostic("manifest.invalid-action-id", "action_id must be a positive integer"))
            continue
        if not isinstance(external_id, str) or not external_id:
            diagnostics.append(Diagnostic("manifest.invalid-external-id", "external_id must be a non-empty string", action_id))
            continue
        if not _is_valid_resource_path(resource_path):
            diagnostics.append(
                Diagnostic(
                    "manifest.malformed-resource-path",
                    "resource_path must be a relative Images/*.gif path without traversal",
                    action_id,
                    external_id,
                    resource_path if isinstance(resource_path, str) else None,
                )
            )
            continue
        valid_mappings.append(mapping)

    action_ids = [mapping["action_id"] for mapping in valid_mappings]
    if action_ids != sorted(action_ids):
        diagnostics.append(Diagnostic("manifest.unsorted-mappings", "mappings must be sorted by action_id"))

    for key, code in (
        ("action_id", "manifest.duplicate-action-id"),
        ("external_id", "manifest.duplicate-external-id"),
        ("resource_path", "manifest.duplicate-resource-path"),
    ):
        seen: set[Any] = set()
        for mapping in valid_mappings:
            value = mapping[key]
            if value in seen:
                diagnostics.append(
                    Diagnostic(code, f"duplicate {key}", mapping["action_id"], mapping["external_id"], mapping["resource_path"])
                )
            seen.add(value)

    actions_by_id = {int(action["id"]): action for action in actions}
    mappings_by_id = {mapping["action_id"]: mapping for mapping in valid_mappings}
    for action_id, action in actions_by_id.items():
        mapping = mappings_by_id.get(action_id)
        if mapping is None:
            diagnostics.append(Diagnostic("mapping.missing", "no manifest mapping", action_id, str(action["external_id"])))
            continue
        if mapping["external_id"] != str(action["external_id"]):
            diagnostics.append(
                Diagnostic(
                    "mapping.external-id-mismatch",
                    "external_id does not match actions.json",
                    action_id,
                    mapping["external_id"],
                    mapping["resource_path"],
                )
            )
        if mapping["resource_path"] != action.get("gifUrl"):
            diagnostics.append(
                Diagnostic(
                    "mapping.resource-path-mismatch",
                    "resource_path does not match actions.json gifUrl",
                    action_id,
                    mapping["external_id"],
                    mapping["resource_path"],
                )
            )

    for action_id, mapping in mappings_by_id.items():
        if action_id not in actions_by_id:
            diagnostics.append(
                Diagnostic(
                    "mapping.unknown-action",
                    "mapping refers to an action absent from actions.json",
                    action_id,
                    mapping["external_id"],
                    mapping["resource_path"],
                )
            )
        elif not (resources_root / mapping["resource_path"]).is_file():
            diagnostics.append(
                Diagnostic(
                    "mapping.asset-missing",
                    "referenced GIF file does not exist",
                    action_id,
                    mapping["external_id"],
                    mapping["resource_path"],
                )
            )

    return valid_mappings, sorted(diagnostics, key=_sort_key)
    return joined
