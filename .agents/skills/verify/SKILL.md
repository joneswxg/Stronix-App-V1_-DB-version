---
name: verify
summary: Build, install, and smoke-test the Stronix iOS app in Simulator.
---

# Verify Stronix in iOS Simulator

Use full Xcode explicitly because the active developer directory may point at Command Line Tools.

1. Build for the available simulator:
   ```bash
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
     -project Stronix-App-V1.xcodeproj \
     -scheme Stronix-App-V1 \
     -configuration Debug \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
     -derivedDataPath /tmp/stronix-verify-derived \
     CODE_SIGNING_ALLOWED=NO build
   ```
2. Boot, install, and launch on the simulator with `xcrun simctl` using the available iPhone 17 Pro UDID.
3. For startup changes, launch with `--console-pty` and confirm database readiness is logged before `MainTabView onAppear`.
4. Capture the visible result with `xcrun simctl io <UDID> screenshot <path>` and inspect the image.
5. Relaunch once without reinstalling to probe persisted startup state.
