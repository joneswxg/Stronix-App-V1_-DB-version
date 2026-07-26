#!/usr/bin/env python3
"""Verify the repository-integrity CI contract."""

from __future__ import annotations

from pathlib import Path
import sys

WORKFLOW = Path(".github/workflows/ios-simulator-build.yml")
README = Path("README.md")
DATABASE_README = Path("tools/database/README.md")
DOC = Path("docs/remediation/phase-8.9-repository-integrity-ci.md")

REQUIRED_JOB_SNIPPETS = {
    "job display name": "name: Repository integrity checks",
    "Linux runner": "runs-on: ubuntu-latest",
    "checkout": "uses: actions/checkout@v7",
    "tracked-noise step": "name: Verify tracked repository noise",
    "tracked-noise command": "sh tools/check_tracked_noise.sh",
    "permissions step": "name: Verify Git index permissions",
    "permissions command": "python3 tools/verify_file_permissions.py",
    "action-image step": "name: Validate action-image manifest",
    "action-image command": "python3 tools/database/validate_action_images.py",
    "action-image tests step": "name: Run action-image manifest tests",
    "action-image tests command": "python3 -m unittest tools.database.tests.test_action_image_manifest",
    "baseline step": "name: Verify bundled SQLite baseline contract",
    "baseline command": "python3 tools/database/generate_baseline_db.py --verify-bundled-baseline",
    "contract checker step": "name: Verify repository-integrity CI contract",
    "contract checker command": "python3 tools/verify_repository_integrity_ci.py",
}

REQUIRED_DOCUMENTATION_SNIPPETS = {
    README: (
        "Repository integrity checks",
        "phase-8.9-repository-integrity-ci.md",
        "--verify-bundled-baseline",
    ),
    DATABASE_README: (
        "--verify-bundled-baseline",
        "read-only",
        "Documents",
        "logical",
    ),
    DOC: (
        "Repository integrity checks",
        "ubuntu-latest",
        "--verify-bundled-baseline",
        "Documents",
        "artifacts",
    ),
}

PROHIBITED_JOB_SNIPPETS = (
    "needs:",
    "xcodebuild",
    "xcrun",
    "simctl",
    "DEVELOPER_DIR",
    "platform=iOS Simulator",
    "actions/upload-artifact@",
)


def repository_integrity_job(workflow: str) -> str | None:
    marker = "  repository-integrity:\n"
    start = workflow.find(marker)
    if start == -1:
        return None

    lines = workflow[start:].splitlines()
    job_lines = [lines[0]]
    for line in lines[1:]:
        if line.startswith("  ") and not line.startswith("    ") and line.endswith(":"):
            break
        job_lines.append(line)
    return "\n".join(job_lines)


def check_workflow_text(workflow: str) -> list[str]:
    job = repository_integrity_job(workflow)
    if job is None:
        return [f"{WORKFLOW}: missing dedicated 'repository-integrity' job"]

    failures = [
        f"{WORKFLOW}: repository-integrity job is missing {label!r} snippet {snippet!r}"
        for label, snippet in REQUIRED_JOB_SNIPPETS.items()
        if snippet not in job
    ]
    failures.extend(
        f"{WORKFLOW}: repository-integrity job includes prohibited snippet {snippet!r}"
        for snippet in PROHIBITED_JOB_SNIPPETS
        if snippet in job
    )
    return failures


def check_documentation() -> list[str]:
    failures: list[str] = []
    for path, snippets in REQUIRED_DOCUMENTATION_SNIPPETS.items():
        if not path.exists():
            failures.append(f"{path}: file is missing")
            continue
        content = path.read_text(encoding="utf-8")
        failures.extend(
            f"{path}: missing required documentation snippet {snippet!r}"
            for snippet in snippets
            if snippet not in content
        )
    return failures


def main() -> int:
    if not WORKFLOW.exists():
        failures = [f"{WORKFLOW}: file is missing"]
    else:
        failures = check_workflow_text(WORKFLOW.read_text(encoding="utf-8"))
    failures.extend(check_documentation())

    if failures:
        print("Repository-integrity CI contract is incomplete:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    print("Repository-integrity CI contract is complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
