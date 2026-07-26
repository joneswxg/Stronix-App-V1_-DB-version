#!/usr/bin/env python3
"""Lint changed, repository-owned Swift files without modifying them."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

FORMATTER_VERSION = "0.58.5"
OWNED_SWIFT_ROOTS = (Path("Stronix-App/Sources"), Path("Stronix-App/Tests"))
CONFIGURATION = Path(".swiftformat")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Lint changed repository-owned Swift files with SwiftFormat."
    )
    parser.add_argument("--base", required=True, help="Revision to compare with HEAD.")
    parser.add_argument(
        "--formatter",
        default="swiftformat",
        help="SwiftFormat executable (default: swiftformat on PATH).",
    )
    return parser.parse_args()


def changed_paths(base: str) -> list[Path]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "-z", "--diff-filter=ACMR", f"{base}...HEAD"],
        check=True,
        capture_output=True,
    )
    return [Path(path) for path in result.stdout.decode().split("\0") if path]


def is_owned_swift_path(path: Path) -> bool:
    return path.suffix == ".swift" and any(
        path.is_relative_to(root) for root in OWNED_SWIFT_ROOTS
    )


def is_tracked(path: Path) -> bool:
    return (
        subprocess.run(
            ["git", "ls-files", "--error-unmatch", "--", str(path)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def changed_owned_swift_paths(base: str) -> list[Path]:
    return [
        path
        for path in changed_paths(base)
        if is_owned_swift_path(path) and path.is_file() and is_tracked(path)
    ]


def verify_formatter_version(formatter: str) -> None:
    result = subprocess.run(
        [formatter, "--version"], check=True, capture_output=True, text=True
    )
    version = result.stdout.strip()
    if version != FORMATTER_VERSION:
        raise RuntimeError(
            f"Expected SwiftFormat {FORMATTER_VERSION}, found {version or 'no version output'}."
        )


def lint(paths: list[Path], formatter: str) -> int:
    return subprocess.run(
        [
            formatter,
            "--lint",
            "--lenient",
            "--reporter",
            "github-actions-log",
            "--config",
            str(CONFIGURATION),
            *(str(path) for path in paths),
        ],
        check=False,
    ).returncode


def main() -> int:
    args = parse_args()
    try:
        paths = changed_owned_swift_paths(args.base)
        if not paths:
            print("No changed owned Swift files to lint.")
            return 0
        if not CONFIGURATION.is_file():
            raise RuntimeError(f"Missing SwiftFormat configuration: {CONFIGURATION}")
        verify_formatter_version(args.formatter)
    except (OSError, subprocess.CalledProcessError, RuntimeError) as error:
        print(f"Changed Swift formatting check failed: {error}", file=sys.stderr)
        return 1

    print(f"Linting {len(paths)} changed owned Swift file(s):")
    for path in paths:
        print(f"- {path}")
    return lint(paths, args.formatter)


if __name__ == "__main__":
    raise SystemExit(main())
