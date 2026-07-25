#!/usr/bin/env python3

import argparse
import json
from pathlib import Path

from action_image_manifest import validate_manifest


def parse_args() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description="Validate Stronix action-image mappings.")
    parser.add_argument("--actions", type=Path, default=script_dir / "seeds" / "actions.json")
    parser.add_argument("--manifest", type=Path, default=script_dir / "seeds" / "action_images.json")
    parser.add_argument(
        "--resources", type=Path, default=script_dir.parents[1] / "Stronix-App" / "Resources"
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        with args.actions.open(encoding="utf-8") as handle:
            actions = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        print(f"ERROR [actions.unreadable]: {error}")
        return 1

    _, diagnostics = validate_manifest(actions, args.manifest, args.resources)
    if diagnostics:
        for diagnostic in diagnostics:
            print(diagnostic.format())
        return 1

    print(f"Validated {len(actions)} action-image mappings.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
