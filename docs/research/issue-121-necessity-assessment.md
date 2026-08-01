# Issue #121 necessity assessment

Date: 2026-08-01

## Question

Does [Issue #121](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/121) still require feature development after [Issue #120](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/120) was completed by [PR #124](https://github.com/joneswxg/Stronix-App-V1_-DB-version/pull/124)?

## Conclusion

No separate production-feature implementation is necessary. PR #124 deliberately bundled the core #120 countdown state machine and essentially all of #121's requested floating-control UI. The evidence indicates that #121 most likely remained open administratively: PR #124 did not link it as a closing issue, while the requested production behavior is already present on `main`.

One explicit acceptance item remains unsupported by evidence: UI-level coverage of the floating control's observable behavior. The repository has behavior-focused timer tests, but no UI/snapshot test that renders the circle or verifies its visibility, displayed time/progress, tap routing, or drag interaction. If manual QA is acceptable, #121 can be closed as implemented by PR #124. If every acceptance criterion must be automated, narrow the remaining work to a test-only follow-up.

## What #120 was for

Issue #120 specified the rest-countdown domain behavior rather than the floating UI:

- One transient countdown owned by the active training session.
- Completing any set, including the final set, starts or restarts it from that action's configured rest interval.
- Unchecking a set does not alter the active countdown; editing an interval affects only the next completion.
- Reset uses the interval captured when that countdown started.
- Natural expiry stays at `00:00`, while manual finish/close dismisses the countdown.
- Background elapsed time is reconciled, but the timer is not restored after app termination.
- Rest-timer state does not enter history or the database schema; total workout duration stays independent.

Source: [Issue #120](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/120). Its closing comment identifies PR #124 as the implementation: [issue comment](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/120#issuecomment-5149625820).

## What #121 was for

Issue #121 was intended as the presentation layer built on #120:

- Remove the always-visible floating capsule that showed total workout duration; retain total duration in the training-page header.
- Show a draggable circular rest countdown only during the rest lifecycle.
- Render a blue decreasing progress ring with centered `mm:ss`, and retain `00:00` after natural expiry.
- On tap, return to the training tab and expose the existing detailed rest controls.
- Hide the circle after manual finish, close, or skip; show it again on a later set completion.
- Add UI coverage based on observable state rather than timer internals.

Source: [Issue #121](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/121).

## Evidence that PR #124 already delivered #121

PR #124's own summary explicitly says it presents a draggable circular rest countdown and opens the existing controls when tapped. The merged implementation is commit [`d1e51ea`](https://github.com/joneswxg/Stronix-App-V1_-DB-version/commit/d1e51ea6e57dc18979d6fe32f81f92a05ccb7aad), containing feature commit [`716abac`](https://github.com/joneswxg/Stronix-App-V1_-DB-version/commit/716abacff5ea19894c221332771a31c9ef358714) and test commit [`b9c8469`](https://github.com/joneswxg/Stronix-App-V1_-DB-version/commit/b9c8469e427c0b2e1707cf43cb929f2aa199ffab).

| #121 acceptance behavior | Current evidence | Assessment |
| --- | --- | --- |
| Remove total-workout floating capsule; keep elapsed duration in header | The indicator is gated by `showRestTimer` and renders a circle instead of the old capsule in `Stronix-App/Sources/Views/Training/TrainingFloatingIndicator.swift:14-43`. The session header still renders `elapsedTimeText` in `Stronix-App/Sources/Views/Training/TrainingView.swift:181-198`. The merge diff shows the old `formattedTrainingTime()` capsule was replaced. | Implemented |
| Hidden before rest, shown after set completion, retained at `00:00` | Initial `showRestTimer` is false; set completion calls `startRestCountdown`, which sets it true (`TrainingSessionManager.swift:60,139-180`). Natural expiry sets time to zero without dismissing (`TrainingSessionManager.swift:199-205`). | Implemented |
| Blue remaining-time ring, centered `mm:ss`, draggable | `Circle.trim`, themed primary stroke, and `restTimerText` appear in `TrainingFloatingIndicator.swift:18-30`; progress is remaining/current duration at lines 46-49; drag behavior is at lines 51-65. The available themes use blue or dark blue primary colors (`Stronix-App/Sources/Theme/AppTheme.swift:21-43`). | Implemented |
| Tap returns to training and opens detailed controls | The tap selects tab 2 and calls `presentRestControls` (`Stronix-App/Sources/Views/MainTabView.swift:68-73`). The training view displays `RestTimerOverlay` when `showRestControls` is true (`TrainingView.swift:125-128`), with detailed actions at lines 539-579. | Implemented |
| Manual finish/close/skip hides; later completion restarts | Finish-rest uses `onSkip` (`TrainingView.swift:562-565`). Skip and close call `dismissRestTimer`, which hides both indicator and controls (`TrainingSessionManager.swift:208-218,247-265`). A later completion starts a fresh countdown (`TrainingSessionManager.swift:139-180`). | Implemented |
| UI coverage of observable state | `Stronix-App/Tests/TrainingViewModelTests.swift:119-194` covers timer state and history isolation, but the repo contains no UI/snapshot test for `TrainingFloatingIndicator`. PR #124 also left its manual authenticated training-session flow unchecked. | Not demonstrated |

## Scope overlap

#120 and #121 were designed as dependent tickets: #120 owns the timer state and lifecycle, while #121 consumes that state in a floating UI. They were not originally duplicates. However, PR #124 crossed the planned ticket boundary and implemented both layers in one change. The PR changed the session manager, view model, main-tab routing, training overlay, floating indicator, and tests together; its summary explicitly records both the state-machine work and the circular UI.

GitHub reports #121 as open and does not list a closing PR. This supports, but does not prove, the inference that the ticket remained open administratively after the feature was bundled into PR #124.

## Recommendation

1. Perform a short manual check: start a workout, complete a set, confirm the circle appears and counts down, drag it, tap it from another tab, verify the detailed controls, let it reach `00:00`, then finish/close it and complete another set.
2. If that passes, comment on #121 that it was implemented by PR #124 and close it. No new production code is warranted.
3. If automated UI coverage is a release requirement, replace #121 with a narrowly scoped test task (or edit #121 to contain only that gap) rather than rebuilding the feature.

## Source inventory

- [Issue #120](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/120)
- [Issue #121](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/121)
- [Parent Issue #118](https://github.com/joneswxg/Stronix-App-V1_-DB-version/issues/118), which records the shared product and testing decisions
- [PR #124](https://github.com/joneswxg/Stronix-App-V1_-DB-version/pull/124)
- Current `main` source at merge commit [`d1e51ea`](https://github.com/joneswxg/Stronix-App-V1_-DB-version/commit/d1e51ea6e57dc18979d6fe32f81f92a05ccb7aad)

This assessment inspected the existing tests and PR test report; it did not rerun the test suite or perform the authenticated manual flow.
