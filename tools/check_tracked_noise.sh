#!/bin/sh

set -eu

repository_root=$(git rev-parse --show-toplevel)
tracked_paths=$(git -C "$repository_root" ls-files)
noise_paths=$(printf '%s\n' "$tracked_paths" | grep -E '(^|/)\.DS_Store$|(^|/)xcuserdata(/|$)|\.(xcuserstate|xcbkptlist|xccheckout|xcscmblueprint|log)$|(^|/)(DerivedData|build|Logs)(/|$)' || true)

if [ -n "$noise_paths" ]; then
    printf '%s\n' "Tracked repository noise detected:"
    printf '%s\n' "$noise_paths"
    exit 1
fi

printf '%s\n' "No tracked repository noise detected."
