import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from action_image_manifest import validate_manifest


class ActionImageManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.resources = self.root / "Resources"
        image = self.resources / "Images" / "triceps" / "exercise_1256.gif"
        image.parent.mkdir(parents=True)
        image.write_bytes(b"GIF89a")
        self.actions = [
            {
                "id": 2,
                "external_id": "1256",
                "gifUrl": "Images/triceps/exercise_1256.gif",
            }
        ]

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def write_manifest(self, mappings: list[dict], schema_version: int = 1) -> Path:
        path = self.root / "action_images.json"
        path.write_text(
            json.dumps({"schema_version": schema_version, "mappings": mappings}),
            encoding="utf-8",
        )
        return path

    def test_valid_manifest_matches_existing_runtime_catalog(self) -> None:
        path = self.write_manifest(
            [
                {
                    "action_id": 2,
                    "external_id": "1256",
                    "resource_path": "Images/triceps/exercise_1256.gif",
                }
            ]
        )

        _, diagnostics = validate_manifest(self.actions, path, self.resources)

        self.assertEqual(diagnostics, [])

    def test_reports_missing_malformed_and_inconsistent_mappings_in_stable_order(self) -> None:
        actions = [
            {"id": 2, "external_id": "1256", "gifUrl": "Images/triceps/exercise_1256.gif"},
            {"id": 3, "external_id": "775", "gifUrl": "Images/triceps/exercise_775.gif"},
        ]
        path = self.write_manifest(
            [
                {
                    "action_id": 2,
                    "external_id": "wrong",
                    "resource_path": "Images/../exercise_1256.gif",
                },
                {
                    "action_id": 9,
                    "external_id": "9",
                    "resource_path": "Images/triceps/missing.gif",
                },
            ]
        )

        _, diagnostics = validate_manifest(actions, path, self.resources)

        self.assertEqual(
            [diagnostic.code for diagnostic in diagnostics],
            [
                "manifest.malformed-resource-path",
                "mapping.missing",
                "mapping.missing",
                "mapping.unknown-action",
            ],
        )
        self.assertEqual([diagnostic.action_id for diagnostic in diagnostics], [2, 2, 3, 9])

    def test_reports_duplicate_paths_and_missing_assets(self) -> None:
        actions = [
            {"id": 2, "external_id": "1256", "gifUrl": "Images/triceps/exercise_1256.gif"},
            {"id": 3, "external_id": "775", "gifUrl": "Images/triceps/exercise_775.gif"},
        ]
        path = self.write_manifest(
            [
                {
                    "action_id": 2,
                    "external_id": "1256",
                    "resource_path": "Images/triceps/exercise_1256.gif",
                },
                {
                    "action_id": 3,
                    "external_id": "775",
                    "resource_path": "Images/triceps/exercise_1256.gif",
                },
            ]
        )

        _, diagnostics = validate_manifest(actions, path, self.resources)

        self.assertEqual(
            [diagnostic.code for diagnostic in diagnostics],
            ["manifest.duplicate-resource-path", "mapping.resource-path-mismatch"],
        )

    def test_reports_missing_asset_after_valid_schema_validation(self) -> None:
        path = self.write_manifest(
            [
                {
                    "action_id": 2,
                    "external_id": "1256",
                    "resource_path": "Images/triceps/missing.gif",
                }
            ]
        )

        _, diagnostics = validate_manifest(self.actions, path, self.resources)

        self.assertEqual(
            [diagnostic.code for diagnostic in diagnostics],
            ["mapping.asset-missing", "mapping.resource-path-mismatch"],
        )

    def test_reports_manifest_path_that_differs_from_runtime_catalog(self) -> None:
        path = self.write_manifest(
            [
                {
                    "action_id": 2,
                    "external_id": "1256",
                    "resource_path": "Images/triceps/exercise_1256.gif",
                }
            ]
        )
        actions = [{"id": 2, "external_id": "1256", "gifUrl": "Images/triceps/other.gif"}]

        _, diagnostics = validate_manifest(actions, path, self.resources)

        self.assertEqual(
            [diagnostic.code for diagnostic in diagnostics],
            ["mapping.resource-path-mismatch"],
        )

    def test_packaged_manifest_matches_canonical_manifest(self) -> None:
        repository_root = Path(__file__).resolve().parents[3]
        canonical_path = repository_root / "tools/database/seeds/action_images.json"
        packaged_path = repository_root / "Stronix-App/Resources/action_images.json"
        actions_path = repository_root / "tools/database/seeds/actions.json"
        resources_path = repository_root / "Stronix-App/Resources"

        self.assertEqual(
            json.loads(packaged_path.read_text(encoding="utf-8")),
            json.loads(canonical_path.read_text(encoding="utf-8")),
        )

        _, diagnostics = validate_manifest(
            json.loads(actions_path.read_text(encoding="utf-8")),
            packaged_path,
            resources_path,
        )

        self.assertEqual(diagnostics, [])


if __name__ == "__main__":
    unittest.main()
