# Phase 0 Baseline

## Status

- Ticket: 0.1 Create remediation baseline
- Status: Completed
- Date: 2026-07-20

## Git Baseline

- Baseline commit: `73424f9`
- Baseline tag: `remediation-baseline-20260720`
- Tag target: `73424f9 docs: add remediation execution breakdown`

## Working Tree Note

At the time the baseline tag was created, the only non-baseline working tree change was `.DS_Store`. That file is repository noise and is intentionally excluded from the remediation baseline.

## Project Build Baseline

- Xcode project: `Stronix-App-V1.xcodeproj`
- Shared scheme file: `Stronix-App-V1.xcodeproj/xcshareddata/xcschemes/Stronix-App-V1.xcscheme`
- Scheme buildable name: `Stronix.app`
- Scheme blueprint name: `Stronix`
- Bundle identifier: `JonesW.Stronix-App-V1`
- Development team: `M3985G54RA`
- iOS deployment target: `18.4`

## Build Tool Availability

Initial `xcodebuild -list -project Stronix-App-V1.xcodeproj` could not run because the active developer directory was Command Line Tools, not full Xcode:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

Full Xcode is installed at `/Applications/Xcode.app`. Running with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` confirmed:

```text
Xcode 26.6
Build version 17F113
```

## Build Verification

Command attempted:

```text
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Stronix-App-V1.xcodeproj -scheme Stronix-App-V1 -destination generic/platform=iOS\ Simulator -derivedDataPath /tmp/stronix-xcode-derived -clonedSourcePackagesDirPath /tmp/stronix-xcode-packages build
```

Result: command-line build not completed in Codex environment.

Swift Package dependencies resolved successfully after network access was allowed:

```text
SQLite.swift: https://github.com/stephencelis/SQLite.swift @ master (392dd60)
swift-toolchain-sqlite: https://github.com/swiftlang/swift-toolchain-sqlite @ 1.0.4
```

The build then failed because no eligible destination/runtime is installed:

```text
xcodebuild: error: Unable to find a destination matching the provided destination specifier:
  { generic:1, platform:iOS Simulator }

Ineligible destinations for the "Stronix-App-V1" scheme:
  { platform:iOS, name:Any iOS Device, error:iOS 26.5 is not installed. Please download and install the platform from Xcode > Settings > Components. }
```

Build verification should be completed after installing the required iOS platform/runtime in Xcode.

## Manual Xcode Verification

The missing runtime issue was resolved outside Codex by opening the project in Xcode, installing/selecting the required platform support, building successfully, launching the simulator, and opening the app.

- Reported by: user
- Date: 2026-07-20
- Result: Build succeeded in Xcode and app launched in simulator
