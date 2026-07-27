# Phase 8.11: P0/P1 Release Quality Gate

## Purpose

[GitHub issue #92](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/92) closes the P0/P1 release-quality gate by recording one release candidate's risk-based automated, CI, and manual verification evidence. It consolidates existing evidence sources; it does not add product behavior, a coverage quota, or a full UI-automation requirement.

The canonical risk mapping is [Phase 8.1 Risk Verification Matrix](phase-8.1-risk-verification-matrix.md). Manual path definitions are in [Manual Regression Checklist](manual-regression.md). The supported command contracts are [Phase 8.7 Deterministic Simulator Build CI](phase-8.7-deterministic-build-ci.md), [Phase 8.9 Repository Integrity CI](phase-8.9-repository-integrity-ci.md), and [Phase 8.10 Advisory Changed-Code Formatting](phase-8.10-advisory-changed-code-formatting.md). CI implementation is [`.github/workflows/ios-simulator-build.yml`](../../.github/workflows/ios-simulator-build.yml); its risk-oriented XCTest plan is [`StronixRiskVerification.xctestplan`](../../Stronix-App-V1.xcodeproj/xcshareddata/xctestplans/StronixRiskVerification.xctestplan).

## Evidence Rules

- A template, planned command, or historical checklist entry is not execution evidence.
- A check is **Pass** only if the documented command or manual path ran for the recorded candidate and produced its expected result.
- **Fail** means a performed check did not produce its expected result. **Blocked** means a concrete prerequisite prevented execution. **Not run** means it was not performed. **Partial** means both performed and deferred/blocked/not-run checks exist; it does not accept this gate.
- Each observed failure or actionable blocker requires a distinct GitHub issue with the candidate SHA, environment, reproduction, expected/actual result, and sanitized evidence. Ordinary scheduling deferrals remain in this record rather than receiving placeholder issues.
- The serial XCTest command below is candidate evidence. It is not currently a GitHub Actions behavioral-test job: the workflow provides Debug/Release compilation, repository integrity, and advisory formatting jobs.
- Automated coverage complements focused manual regression. It does not replace controlled-container upgrade, installed-app session/Keychain, rendered UI, navigation, chart, accessibility, or real-simulator persistence checks.

## Candidate Execution Record

### Candidate and environment

| Field | Value |
| --- | --- |
| Date | 2026-07-27 |
| Candidate commit | `0f600257ab5a90190a4cd9d963a8f2d5e8b608a8` (pre-documentation candidate) |
| Branch | `feature/Phase-8.10-Phase-8.11-Complete-the-P0/P1-release-qualitygate` |
| Repository state before execution | Documentation changes uncommitted: `README.md`, `manual-regression.md`, `phase-8.1-risk-verification-matrix.md`, and this record. |
| Tester | Claude Code |
| `DEVELOPER_DIR` | `/Applications/Xcode.app/Contents/Developer` |
| Xcode version | Xcode 26.6, build 17F113 |
| Simulator/device and UDID | iPhone 17 Pro (`913B9C86-EFD4-4D99-86F7-F9CAE2640483`) |
| iOS runtime | iOS 26.5 (23F77) |
| CI run/check evidence | Local commands only; no CI run inspected. |
| Overall result | Blocked — automated build/test/integrity checks passed, but pinned local SwiftFormat is unavailable and the required controlled authenticated manual regression was not performed. |

### Automated and supporting checks

Run commands sequentially for the recorded candidate. Do not build or install the app on the selected simulator while the serial XCTest command is active. The documented Phase 8.7 preflight must confirm Xcode 26.6 (17F113), iOS 26.5, and iPhone 17 Pro before build execution.

| Check | Reproducible command | Result | Performed evidence / deferral |
| --- | --- | --- | --- |
| Phase 8.7 Debug build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Stronix-App-V1.xcodeproj -scheme Stronix-App-V1 -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/stronix-ci-debug-derived-data -clonedSourcePackagesDirPath /tmp/stronix-ci-debug-source-packages -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -disablePackageRepositoryCache CODE_SIGNING_ALLOWED=NO build` | Pass | Completed against the recorded pre-documentation candidate; `** BUILD SUCCEEDED **`. |
| Phase 8.7 Release build | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Stronix-App-V1.xcodeproj -scheme Stronix-App-V1 -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -derivedDataPath /tmp/stronix-ci-release-derived-data -clonedSourcePackagesDirPath /tmp/stronix-ci-release-source-packages -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -disablePackageRepositoryCache CODE_SIGNING_ALLOWED=NO build` | Pass | Completed against the recorded pre-documentation candidate; `** BUILD SUCCEEDED **`. |
| Locked package resolution | `git diff --exit-code -- Stronix-App-V1.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Pass | Passed after each Phase 8.7 build. |
| Serial risk XCTest | `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Stronix-App-V1.xcodeproj -scheme Stronix-App-V1 -testPlan StronixRiskVerification -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -derivedDataPath /tmp/stronix-phase-8-11-risk-tests CODE_SIGNING_ALLOWED=NO test` | Pass | Completed without an overlapping app build/install. `** TEST SUCCEEDED **`: 193 tests, 0 failures. |
| Tracked repository noise | `sh tools/check_tracked_noise.sh` | Pass | `No tracked repository noise detected.` |
| Git-index permissions | `python3 tools/verify_file_permissions.py` | Pass | `permission verification passed; intended executables: 1`. |
| Action-image manifest | `python3 tools/database/validate_action_images.py && python3 -m unittest tools.database.tests.test_action_image_manifest` | Pass | Validated 272 mappings; 6 tests passed. |
| Bundled baseline contract | `python3 tools/database/generate_baseline_db.py --verify-bundled-baseline && python3 -m unittest tools.database.tests.test_bundled_baseline_contract` | Pass | Bundled source baseline verified; 4 tests passed. |
| Integrity CI contract | `python3 -m unittest tools.tests.test_repository_integrity_ci && python3 tools/verify_repository_integrity_ci.py` | Pass | 4 tests passed; repository-integrity CI contract complete. |
| Advisory changed-owned-Swift formatting | `swiftformat --version && git fetch origin main && python3 tools/lint_changed_swift_format.py --base "$(git merge-base origin/main HEAD)"` | Blocked | `swiftformat` was unavailable (`command not found`, exit 127), so lint did not run. Follow-up: [#102](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/102). |

### Focused manual P0/P1 evidence

| Matrix outcome | Required observed path | Result | Performed evidence / deferral |
| --- | --- | --- | --- |
| Database readiness | Clean startup; controlled-container upgrade retaining a User Plan, history, and body measurement; relaunch. | Partial | Debug app installed and launched to the signed-out body-measurement overview without a visible blocking readiness error; screenshot captured at `/tmp/stronix-phase-8-11-settled.png`. Controlled-container upgrade and settled relaunch were not performed. |
| Authentication and session | Registration/login behavior; force-quit restoration; logout; User A → User B → User A isolation; Release-console review for credentials, session values, and cross-user data. | Not run | No controlled User A/User B account and data setup was available, and no interactive UI driver was configured. Release console review was not performed. |
| Template and User Plans | Browse a Template Plan without personal-training start; copy and edit it without source mutation; create/edit/delete a disposable User Plan; relaunch. | Not run | Requires controlled authenticated account/data setup and interactive operation. |
| Training and history | Start an eligible User Plan, edit an actual set, complete once, inspect matching ordered history/detail/statistics, and relaunch. | Not run | Requires controlled authenticated account/data setup and interactive operation. |
| Body measurement | Add/edit/delete, overview/list/detail/change/chart refresh, User A/User B isolation, and relaunch persistence. | Not run | Signed-out overview was visible; authenticated lifecycle, isolation, and persistence were not performed without controlled accounts/data and interactive operation. |
| Body-measurement failure/retry | Induce a safe, controllable persistence failure only when reproducible; verify retained form/data and retry. | Not run | No safe controllable persistence failure was configured; no evidence was manufactured. |

### Deferred checks and follow-up issues

- Deferred or blocked checks: local pinned SwiftFormat installation ([#102](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/102)); controlled authenticated User A/User B manual data setup; controlled-container upgrade; Release-console review; and interactive manual paths.
- Follow-up issues: [#102](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/102) — local SwiftFormat 0.58.5 unavailable. No product failure was observed.

## Completion Rule

Mark the overall result **Pass** only after every required automated, CI/supporting, and manual path above has been performed against one recorded candidate and no required release check remains deferred. If a required check is not run, blocked, or fails, record its actual status and reason; do not infer success from this document or an unchecked checklist.
