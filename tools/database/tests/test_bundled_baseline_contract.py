import hashlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from generate_baseline_db import verify_bundled_baseline


class BundledBaselineContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repository_root = Path(__file__).resolve().parents[3]
        self.script = self.repository_root / "tools/database/generate_baseline_db.py"
        self.bundle = (
            self.repository_root
            / "Stronix-App/Resources/Database/database_stronix.db"
        )

    def test_checked_in_bundle_matches_generated_source_baseline(self) -> None:
        generated, bundled = verify_bundled_baseline(self.bundle)

        self.assertEqual(generated, bundled)

    def test_cli_verification_does_not_modify_bundled_database(self) -> None:
        before_hash = hashlib.sha256(self.bundle.read_bytes()).hexdigest()
        before_stat = self.bundle.stat()

        result = subprocess.run(
            [sys.executable, str(self.script), "--verify-bundled-baseline"],
            cwd=self.repository_root,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Verified bundled source baseline:", result.stdout)
        self.assertIn("Logical fingerprint:", result.stdout)
        self.assertEqual(hashlib.sha256(self.bundle.read_bytes()).hexdigest(), before_hash)
        self.assertEqual(self.bundle.stat().st_mtime_ns, before_stat.st_mtime_ns)
        self.assertEqual(
            list(self.bundle.parent.glob(f"{self.bundle.name}-*"))
            + list(self.bundle.parent.glob(f".{self.bundle.name}.*.tmp")),
            [],
        )

    def test_reports_logical_contract_mismatch_for_temporary_bundle_copy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            modified_bundle = Path(directory) / "database_stronix.db"
            shutil.copyfile(self.bundle, modified_bundle)
            import sqlite3

            connection = sqlite3.connect(modified_bundle)
            try:
                cursor = connection.execute(
                    "UPDATE body_part SET name = 'changed' WHERE id = (SELECT MIN(id) FROM body_part)"
                )
                self.assertEqual(cursor.rowcount, 1)
                connection.commit()
            finally:
                connection.close()

            with self.assertRaisesRegex(
                ValueError, "Bundled source baseline logical contract mismatch"
            ):
                verify_bundled_baseline(modified_bundle)

    def test_reports_missing_bundle_path(self) -> None:
        with self.assertRaisesRegex(ValueError, "Bundled source baseline is missing"):
            verify_bundled_baseline(Path("/missing/database_stronix.db"))


if __name__ == "__main__":
    unittest.main()
