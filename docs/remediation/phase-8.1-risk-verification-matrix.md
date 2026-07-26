# Phase 8.1 Risk Verification Matrix

## Purpose

This matrix makes the current P0/P1 release risks traceable to an automated seam and a required manual complement. It is risk-based: it prioritizes data loss, ownership leakage, session leakage, and broken core flows. It does not set a blanket coverage-percentage target and does not require broad UI automation.

The CI-oriented automated suite is `StronixRiskVerification.xctestplan`. It runs the complete `StronixTests` target serially until shared-state and simulator-install parallel safety are proven separately.

## Matrix

| Priority | Risk outcome | Automated seam and evidence | Required manual complement | Remaining gap |
| --- | --- | --- | --- | --- |
| P0 | A valid bundled baseline initializes a separate mutable database; upgrades preserve user data; failed migrations restore safely; unsupported or invalid databases never become ready. | `DatabaseLifecycleTests` covers baseline validation, deterministic seeds, migration ordering, existing-data preservation, rollback, snapshot recovery, incompatibility, retry, explicit rebuild, and concurrent preparation. `IsolatedDatabaseFixtureTests` proves lifecycle writes stay under a unique test root and differ from the app Documents database and bundled source. | Execute **App Startup** and **App Relaunch Data Persistence** in `manual-regression.md`. For an upgrade candidate, install over a controlled container holding a user plan, training history, and body measurement; verify all survive startup and relaunch. | Automated tests intentionally use synthetic fixture roots rather than a previously installed production app container. The controlled-container upgrade remains a release check. |
| P0 | Template Plans remain immutable; creating, copying, editing, deleting, reopening, and starting eligible User Plans preserves ordered content, atomic persistence, and authenticated ownership. | `PlanRepositoryTests` covers seeded templates, copy fidelity, real ownership, pseudo/missing-owner rejection, forged owner-ID rejection across create/copy/update/delete, ordered action/set persistence, validation, successful deletion with action/set cascades, injected SQLite failure rollback for create/copy/update, and personal-training entry for a detailed User Plan while rejecting Template Plans and empty plans. `CopyTemplatePlanUseCaseTests`, `UpdatePlanUseCaseTests`, `CreatePlanViewModelTests`, `EditPlanViewModelTests`, and `PlanViewModelTests` cover use-case and presentation-state seams. | Execute **Browse And Use Template Plan**, **Create Training Plan**, **Edit Training Plan**, **Delete Training Plan**, and **Start Training**. Reopen created/copied/edited User Plans and their source Template Plans after relaunch; confirm a deleted User Plan stays absent and a Template Plan has no personal-training start path. | No broad UI automation is required in this phase; navigation, field editing, relaunch behavior, and visual confirmation remain manual. |
| P0 | Completing training saves history once, preserves recoverable retry behavior, and exposes owner-scoped ordered history details. | `CompleteTrainingUseCaseTests` covers history-before-plan ordering, history failure, recoverable plan-update failure, and retry without duplicate history. `TrainingHistoryRepositoryTests`, `ActionHistoryRepositoryTests`, `TrainingViewModelTests`, and history view-model tests cover persistence, ordering, filtering, bilateral sets, ownership, retry, and safe error states. | Execute **Start Training**, **Complete Training And Save History**, and **View Training History**. Confirm one completed record, matching actions/sets, stable history/statistics views, and persistence after relaunch. | The active-session-to-rendered-history path crosses UI, timer, and simulator state and remains a focused manual regression rather than a blanket UI test suite. |
| P0 | Registration and login preserve non-disclosing credential behavior; protected session restore/logout/account switching cannot leak the previous user's state. | `SQLiteAuthRepositoryTests` covers registration, login, indistinguishable invalid credentials, duplicate identifiers, and legacy credential upgrade. `AuthenticationUseCasesTests` injects Result-backed repositories, isolated defaults, and in-memory/recording session stores. `UserSessionTests` covers restore, logout failure, scope reset, and account switching. `IsolatedDatabaseFixtureTests` proves session tests use `InMemoryLocalSessionStore` rather than real Keychain state. | Execute **Login**, **Logout**, and **Phase 5.3: User Session And Account Switching**, including force-quit/relaunch after registration, logout, and user switches. Review Release console output for credential/session leakage. | Real Keychain persistence and operating-system relaunch behavior are intentionally not exercised by the unit suite; they remain a controlled Release check. |
| P1 | Body measurements are authenticated-user scoped; create/update/delete preserve canonical data; all user-scoped screens refresh without cross-account leakage. | `BodyMeasurementRepositoryTests` covers owner scoping, ordering, CRUD, typed validation, canonical timestamps, legacy date parsing, and non-disclosing failures. `BodyMeasurementViewModelTests` covers shared state, selection, refresh, recovery, and reset behavior. | Execute **Add Body Measurement** and **Shared Body Measurement State and Profile**, including edit/delete, overview/list/detail/chart refresh, User A → User B → User A switching, and relaunch persistence. | Cross-screen layout, chart interaction, and selection presentation remain manual accessibility and state checks. |
| P1 | User-facing loading, empty, retry, localization, appearance, Dynamic Type, and VoiceOver behavior remains usable while core business assertions stay unchanged. | Existing view-model tests cover loading/success/empty/error/retry states at Repository or UseCase seams. The serial plan guards the business suite against nondeterministic overlap. | Execute the **Phase 6.5 Shared Visual, Localization, and Accessibility Protocol** on applicable pilot surfaces in Light/Dark, Simplified Chinese, accessibility Dynamic Type, and VoiceOver. | This phase does not add broad screenshot or UI automation. Findings should become focused follow-up tickets rather than expanding this foundation. |

## Isolation Contract

Persistence-backed automated tests must:

1. Create a unique fixture root below the XCTest process temporary directory.
2. Copy the bundled baseline before opening a mutable repository database, or inject the baseline as read-only input while `DatabaseLifecycle` copies it into fixture-owned Documents.
3. Never use `DatabaseEnvironment.application().databaseURL` as a mutable test target.
4. Never depend on a pre-existing simulator app container.
5. Inject `InMemoryLocalSessionStore` or a recording `LocalSessionStore`; never read or write real Keychain state.
6. Release repositories and SQLite connections before deleting the fixture root.

## CI Invocation

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project Stronix-App-V1.xcodeproj \
  -scheme Stronix-App-V1 \
  -testPlan StronixRiskVerification \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -derivedDataPath /tmp/stronix-phase-8-1-tests \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Do not run an app install/build against the same simulator while this command is active. A concurrent install can replace the hosted test bundle and invalidates the result even when no assertion fails.
