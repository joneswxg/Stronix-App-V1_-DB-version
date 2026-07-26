# Phase 8.7 Deterministic Simulator Build CI

## Operational scope

The requirements and acceptance criteria for this gate remain canonical in [GitHub issue #88](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/88). This guide records how to execute that approved gate in CI and locally; it does not introduce a separate specification.

The `iOS Simulator Builds` GitHub Actions workflow gives every pull request, plus pushes to `main`, independently named Debug and Release compilation results from a declared Xcode and simulator environment. It is the first Phase 8 CI gate and intentionally covers compilation only.

This gate does **not** run XCTest or style checks, boot or install the app in a simulator, create signed archives, deploy, or distribute builds. Those concerns remain separate follow-on work.

## Declared build inputs

Run the commands below from the repository root with:

- macOS and full Xcode 26.6 (build 17F113) installed; CI uses `/Applications/Xcode_26.6.app`, while a local installation may use `/Applications/Xcode.app`
- the iOS 26.5 simulator runtime and an iPhone 17 Pro simulator available
- project `Stronix-App-V1.xcodeproj`
- shared scheme `Stronix-App-V1`
- the Git-tracked scheme at `Stronix-App-V1.xcodeproj/xcshareddata/xcschemes/Stronix-App-V1.xcscheme`
- the Git-tracked Swift package resolution at `Stronix-App-V1.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

CI selects Xcode explicitly instead of relying on the hosted runner's default Xcode. Locally, export the path for the Xcode 26.6 app installed on the Mac; the standard local path is:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

If the local app is version-named like the hosted image, use `/Applications/Xcode_26.6.app/Contents/Developer` instead. Confirm either selection with `xcodebuild -version` before building.

## Preflight

Run this validation from the repository root. It reports the same inputs as CI and exits unsuccessfully if the required Xcode, runtime, device, shared scheme, or package resolution is unavailable:

```bash
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
python3 - <<'PY'
import json
import os
import subprocess

expected_xcode = "Xcode 26.6\nBuild version 17F113"
developer_dir = os.environ.get(
    "DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"
)
environment = {**os.environ, "DEVELOPER_DIR": developer_dir}

xcode_version = subprocess.check_output(
    ["xcodebuild", "-version"], env=environment, text=True
).strip()
print(xcode_version)
if xcode_version != expected_xcode:
    raise SystemExit(f"Expected {expected_xcode!r}.")

runtimes = json.loads(
    subprocess.check_output(
        ["xcrun", "simctl", "list", "runtimes", "available", "-j"],
        env=environment,
        text=True,
    )
)["runtimes"]
runtime = next(
    (
        candidate
        for candidate in runtimes
        if candidate.get("name") == "iOS 26.5"
        and candidate.get("isAvailable", True)
    ),
    None,
)
if runtime is None:
    raise SystemExit("Required iOS 26.5 simulator runtime is unavailable.")

devices = json.loads(
    subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        env=environment,
        text=True,
    )
)["devices"]
matching_devices = [
    device
    for device in devices.get(runtime["identifier"], [])
    if device.get("name") == "iPhone 17 Pro"
    and device.get("isAvailable", True)
]
if not matching_devices:
    raise SystemExit("Required iPhone 17 Pro is unavailable for iOS 26.5.")

scheme = "Stronix-App-V1.xcodeproj/xcshareddata/xcschemes/Stronix-App-V1.xcscheme"
resolved = "Stronix-App-V1.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
subprocess.run(["git", "ls-files", "--error-unmatch", scheme], check=True)
subprocess.run(["git", "ls-files", "--error-unmatch", resolved], check=True)

with open(resolved, encoding="utf-8") as resolved_file:
    pins = json.load(resolved_file)["pins"]

print(f"Destination: platform=iOS Simulator,name={matching_devices[0]['name']},OS=26.5")
print(f"Shared scheme: Stronix-App-V1 ({scheme})")
print("Resolved Swift package revisions:")
for pin in pins:
    state = pin["state"]
    requirement = state.get("version") or state.get("branch") or "revision"
    print(f"- {pin['identity']}: {requirement} @ {state['revision']}")
PY
```

Expected toolchain output begins with:

```text
Xcode 26.6
Build version 17F113
```

The simulator output must include an available `iOS 26.5` runtime and `iPhone 17 Pro` device.

## Debug build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project Stronix-App-V1.xcodeproj \
  -scheme Stronix-App-V1 \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/stronix-ci-debug-derived-data \
  -clonedSourcePackagesDirPath /tmp/stronix-ci-debug-source-packages \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackageUpdates \
  -disablePackageRepositoryCache \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Release build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project Stronix-App-V1.xcodeproj \
  -scheme Stronix-App-V1 \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /tmp/stronix-ci-release-derived-data \
  -clonedSourcePackagesDirPath /tmp/stronix-ci-release-source-packages \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackageUpdates \
  -disablePackageRepositoryCache \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Debug and Release use separate DerivedData and package checkout directories, matching CI's job-scoped isolation. Do not point concurrent builds at the same paths.

A fresh package checkout directory may fetch the revisions already recorded in `Package.resolved`. The package flags prevent Xcode from selecting newer versions or revisions; they do not require the locked sources to have been downloaded previously.

## Expected result

Each command should finish with:

```text
** BUILD SUCCEEDED **
```

The checked-in package resolution must remain unchanged:

```bash
git diff --exit-code -- \
  Stronix-App-V1.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

## Troubleshooting

- **Wrong Xcode version:** confirm `DEVELOPER_DIR` points to the installed Xcode 26.6 developer directory (normally `/Applications/Xcode.app/Contents/Developer` locally) and `xcodebuild -version` reports build 17F113.
- **Missing destination:** install the iOS 26.5 simulator runtime in Xcode and confirm `xcrun simctl list devices available` includes iPhone 17 Pro under that runtime.
- **Package checkout failure:** confirm the locked revisions are reachable from the current network. Do not remove the package-resolution flags or update `Package.resolved` merely to make the build proceed.
- **Package resolution changed:** inspect the diff and stop. A deterministic build must consume, not rewrite, the checked-in resolution.
- **Signing failure:** confirm `CODE_SIGNING_ALLOWED=NO` is present and the destination is an iOS Simulator rather than a physical device.
