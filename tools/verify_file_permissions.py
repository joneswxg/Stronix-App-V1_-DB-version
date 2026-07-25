#!/usr/bin/env python3

from pathlib import Path
import subprocess
import sys

INTENDED_EXECUTABLES: frozenset[str] = frozenset({
    "tools/check_tracked_noise.sh",
})


def tracked_modes(repository_root: Path) -> dict[str, str]:
    result = subprocess.run(
        ["git", "-C", str(repository_root), "ls-files", "--stage", "-z"],
        check=True,
        capture_output=True,
        text=True,
    )
    modes: dict[str, str] = {}
    for entry in result.stdout.rstrip("\0").split("\0"):
        metadata, separator, path = entry.partition("\t")
        if not separator:
            raise ValueError(f"Unexpected git index entry: {entry}")
        mode, _, _ = metadata.split(maxsplit=2)
        modes[path] = mode
    return modes


def main() -> int:
    repository_root = Path(__file__).resolve().parent.parent
    modes = tracked_modes(repository_root)
    unexpected_executables = sorted(
        path
        for path, mode in modes.items()
        if mode == "100755" and path not in INTENDED_EXECUTABLES
    )
    invalid_intended_executables = sorted(
        path
        for path in INTENDED_EXECUTABLES
        if modes.get(path) != "100755"
    )

    if unexpected_executables or invalid_intended_executables:
        for path in unexpected_executables:
            print(f"unexpected executable: {path}", file=sys.stderr)
        for path in invalid_intended_executables:
            print(f"intended executable is missing or non-executable: {path}", file=sys.stderr)
        return 1

    print(f"permission verification passed; intended executables: {len(INTENDED_EXECUTABLES)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
