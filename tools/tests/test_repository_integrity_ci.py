import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from verify_repository_integrity_ci import check_workflow_text


VALID_JOB = """  repository-integrity:
    name: Repository integrity checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - name: Verify tracked repository noise
        run: sh tools/check_tracked_noise.sh
      - name: Verify Git index permissions
        run: python3 tools/verify_file_permissions.py
      - name: Validate action-image manifest
        run: python3 tools/database/validate_action_images.py
      - name: Run action-image manifest tests
        run: python3 -m unittest tools.database.tests.test_action_image_manifest
      - name: Verify bundled SQLite baseline contract
        run: python3 tools/database/generate_baseline_db.py --verify-bundled-baseline
      - name: Run bundled-baseline contract tests
        run: python3 -m unittest tools.database.tests.test_bundled_baseline_contract
      - name: Verify repository-integrity CI contract
        run: python3 tools/verify_repository_integrity_ci.py
"""


class RepositoryIntegrityCIContractTests(unittest.TestCase):
    def test_accepts_complete_linux_job(self) -> None:
        self.assertEqual(check_workflow_text("jobs:\n" + VALID_JOB), [])

    def test_reports_missing_independent_check(self) -> None:
        workflow = ("jobs:\n" + VALID_JOB).replace(
            "      - name: Verify Git index permissions\n"
            "        run: python3 tools/verify_file_permissions.py\n",
            "",
        )

        failures = check_workflow_text(workflow)

        self.assertTrue(any("permissions step" in failure for failure in failures))
        self.assertTrue(any("permissions command" in failure for failure in failures))

    def test_rejects_simulator_coupling(self) -> None:
        workflow = "jobs:\n" + VALID_JOB.replace(
            "    runs-on: ubuntu-latest",
            "    runs-on: macos-26\n    env:\n      DEVELOPER_DIR: /Applications/Xcode.app\n    needs: build",
        )

        failures = check_workflow_text(workflow)

        self.assertTrue(any("Linux runner" in failure for failure in failures))
        self.assertTrue(any("DEVELOPER_DIR" in failure for failure in failures))
        self.assertTrue(any("needs:" in failure for failure in failures))

    def test_rejects_artifact_upload(self) -> None:
        workflow = "jobs:\n" + VALID_JOB.replace(
            "      - name: Verify repository-integrity CI contract",
            "      - uses: actions/upload-artifact@v4\n      - name: Verify repository-integrity CI contract",
        )

        failures = check_workflow_text(workflow)

        self.assertTrue(any("actions/upload-artifact@" in failure for failure in failures))


if __name__ == "__main__":
    unittest.main()
