# Manual Regression Checklist

## Status

- Ticket: 0.3 Establish manual regression checklist
- Checklist status: Created
- Manual execution status: Startup verified
- Date: 2026-07-20

## Environment Note

The checklist was created during Phase 0. It has not been executed in this environment.

Initial `xcodebuild` usage failed because the active developer directory was Command Line Tools:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

Running with full Xcode selected through `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` resolved Swift Package dependencies, but build verification still could not complete because the required iOS platform/runtime is not installed:

```text
xcodebuild: error: Unable to find a destination matching the provided destination specifier:
  { generic:1, platform:iOS Simulator }

Ineligible destinations for the "Stronix-App-V1" scheme:
  { platform:iOS, name:Any iOS Device, error:iOS 26.5 is not installed. Please download and install the platform from Xcode > Settings > Components. }
```

The missing runtime issue was resolved outside Codex. The user reported that the app built successfully in Xcode, the simulator opened, and the app launched.

## Execution Record Template

- Date:
- Commit:
- Tag:
- Device or simulator:
- iOS version:
- Build configuration:
- Tester:
- Result: Pass / Fail / Partial
- Notes:

## Manual Execution Record

- Date: 2026-07-20
- Commit: `73424f9`
- Tag: `remediation-baseline-20260720`
- Device or simulator: iOS Simulator
- iOS version: Xcode-managed simulator runtime
- Build configuration: Xcode build
- Tester: User
- Result: Partial
- Notes: User reported successful Xcode build, simulator launch, and app startup. Deeper business-flow regression paths remain pending for later phase gates.

## Phase 1 Execution Record Template

- Date:
- Commit:
- Device or simulator:
- iOS version:
- Build configuration:
- Tester:
- Database diagnostic summary:
- Result: Pass / Fail / Partial
- Follow-up issues:
- Notes:

## Phase 1 Manual Execution Record

- Date: 2026-07-22
- Commit: `d4cc32e`
- Device or simulator: iPhone 17 Simulator
- iOS version: 26.5
- Build configuration: Debug
- Tester: User
- Database diagnostic summary: Clean-install startup reached the login UI without a blocking readiness error.
- Result: Pass
- Follow-up issues: None.
- Notes: The full XCTest suite passed. User verified registration, login, logout, body-measurement creation, template-plan use, standalone User Plan creation, User Plan editing and saving, template-copy ownership/isolation, training execution, training-history recording, history-detail/statistics views, relaunch persistence, and small-tool functionality. Templates are used to create personal plans; editing and saving the personal plan does not alter the original template.

## Core Smoke Paths

### 1. App Startup

**Steps**:

1. Launch the app.
2. Wait for the main UI to settle.
3. Watch for database initialization errors.

**Expected**:

- App launches without crash.
- Main navigation is visible.
- No blocking database error appears.

**Result**: Pass, reported by user on 2026-07-20

### 2. Login

**Steps**:

1. Open the login flow.
2. Log in with an existing local user.
3. Confirm the profile or authenticated state is visible.

**Expected**:

- Login succeeds for valid credentials.
- User session is reflected in profile and dependent pages.

**Result**: Pass, verified by user on 2026-07-22

### 3. Logout

**Steps**:

1. From an authenticated session, log out.
2. Navigate back to protected flows.

**Expected**:

- Session is cleared.
- Protected user data is not shown as if still logged in.

**Result**: Pass, verified by user on 2026-07-22

### 4. Browse And Use Template Plan

**Steps**:

1. Sign in with a local user.
2. Open the template plan list and inspect a seeded template.
3. Use the template to add it to the signed-in user's plans.
4. Edit and save the resulting User Plan.
5. Reopen the original template.

**Expected**:

- Seeded templates are visible and browsable.
- The resulting User Plan belongs only to the signed-in user.
- Editing the User Plan does not alter the template.

**Result**: Pass, verified by user on 2026-07-22

### 5. Create Training Plan

**Steps**:

1. Open training plans.
2. Create a new User Plan.
3. Add at least one action.
4. Configure sets, reps, weight, and rest.
5. Save the plan.

**Expected**:

- Plan saves successfully.
- Plan appears in the user plan list.
- Reopening the plan shows the saved values.

**Result**: Pass, verified by user on 2026-07-22

### 6. Edit Training Plan

**Steps**:

1. Open an existing User Plan.
2. Modify name, actions, or set values.
3. Save changes.
4. Reopen the plan.

**Expected**:

- Changes persist.
- No duplicate or missing actions are introduced.

**Result**: Pass, verified by user on 2026-07-22

### 7. Start Training

**Steps**:

1. Open an existing User Plan.
2. Start a training session.
3. Edit actual reps or weights for at least one set.
4. Trigger rest timer behavior if available.

**Expected**:

- Training screen opens.
- Set changes are reflected in the active session.
- Timer behavior does not block core recording.

**Result**: Pass, verified by user on 2026-07-22

### 8. Complete Training And Save History

**Steps**:

1. Complete an active training session.
2. Confirm save.
3. Navigate to history.

**Expected**:

- Training completion succeeds.
- A Training History record appears.
- History details show the completed actions and sets.

**Result**: Pass, verified by user on 2026-07-22

### 9. View Training History

**Steps**:

1. Open the history tab.
2. Open a training history detail.
3. Check statistics or analysis views if available.

**Expected**:

- History list loads.
- Detail screen matches the saved training.
- Statistics pages do not crash.

**Result**: Pass, verified by user on 2026-07-22

### 10. Add Body Measurement

**Steps**:

1. Open body measurement.
2. Add a new measurement.
3. Save and return to the list or overview.

**Expected**:

- Measurement saves successfully.
- New value appears in list or overview.

**Result**: Pass, verified by user on 2026-07-22

### 11. Shared Body Measurement State and Profile

**Steps**:

1. Sign in as User A and add at least two body measurements.
2. Open overview, list, detail, and change; edit one record's date and values, then confirm the same persisted record remains selected in detail and all screens refresh.
3. Delete the selected record from detail; confirm overview, list, and change no longer show it and selection moves to a remaining record or the explicit empty state.
4. Log out, sign in as User B, and confirm no User A measurements, charts, selections, or sheets appear. Log back in as User A and confirm persisted records reload.
5. Open Profile → User Info for a user with populated and unset profile values. Confirm gender, height, and weight match the active user, unsupported fields are absent, and the screen explicitly states that editing is unavailable.

**Expected**:

- Overview, list, detail, edit, and change observe one user-scoped persisted record set.
- Add, date/value edit, and delete immediately update all affected screens without stale or sample data.
- Account transitions clear the outgoing scope before loading the next user.
- Profile shows only actual persisted fields and does not expose a no-op save action.

**Result**: Pending manual verification

### 12. App Relaunch Data Persistence

**Steps**:

1. Quit the app.
2. Relaunch.
3. Recheck user session, plans, history, and body measurements.

**Expected**:

- Local data persists.
- No startup migration or database copy loses user data.

**Result**: Pass, verified by user on 2026-07-22

## Phase 5.1: Local Password Reset Release Gate

**Steps**:

1. Build and launch the **Release** configuration.
2. Open Login and select “忘记密码？”.
3. Confirm the unavailable explanation appears immediately.
4. Confirm there is no email, verification-code, or new-password form; resend action; success message; or route into a reset flow.
5. Dismiss the sheet and verify normal login remains available.
6. Review the Xcode console during this flow.

**Expected**:

- The sheet states that password reset is unavailable for local on-device accounts.
- The only available action dismisses or returns to login.
- No reset operation reports success or changes account state.
- Console output includes no password, reset code, mail key/configuration, recipient, or mail-provider response.

**Result**: Pending manual Release verification

## Phase 5.3: User Session And Account Switching

### Authentication and restoration

1. Launch after clearing the app container and confirm the restoring UI settles to unauthenticated without briefly exposing protected data.
2. Register a local account, force-quit, and relaunch; confirm the protected session restores the same user.
3. Verify correct login succeeds and wrong-password/unknown-email attempts show the same safe message.
4. Verify duplicate email and username registration errors are clear and invalid registration input does not create an account.
5. Open “忘记密码？” and confirm only the local-account unavailable disclosure is shown.

### Logout and account isolation

1. As User A, create a User Plan, training history, and body measurement, then start an active training session.
2. Load plans, history/statistics, and body-measurement views, then log out.
3. Confirm the protected session clears, active training/timers stop, and all User A lists, selections, sheets, and navigation state disappear.
4. Log in as User B and confirm no User A plan, history, measurement, or active training state appears.
5. Log out User B and log back in as User A; confirm User A’s database-backed business data is still present.
6. Force-quit and relaunch after each account transition to confirm the persisted session matches the last successful login/logout.

### Production authentication gate

1. Build and launch Release configuration.
2. Confirm no WeChat/social login, fixed OpenID, demo credential, deterministic token, or simulated authentication success is reachable.
3. Review the console during registration, login, restoration, logout, and account switching; confirm it contains no passwords, stored credentials, session references, or cross-user data.

**Expected**:

- `UserSession` is the consistent authentication source across Profile, plans, training, history, and body measurements.
- A failed protected-session clear does not present a false successful logout.
- Logout clears only the persisted session and in-memory user scope; it never deletes account or business rows.
- No late User A request repopulates state after logout or User B login.

**Result**: Pending manual Release verification

## Phase Completion Rule

For Phase 1, execute every path above on a real simulator or device. Record the database diagnostic summary and actual result in the Phase 1 execution record. Every failure or blocked item must link to a follow-up GitHub issue; do not silently leave a failed release-gate check unresolved.
