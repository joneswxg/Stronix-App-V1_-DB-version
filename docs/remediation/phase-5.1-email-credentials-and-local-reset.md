# Phase 5.1: Email Credentials And Local Reset

## Decision

Stronix local accounts are stored on one device. This release does not offer password reset because there is no trusted server-side identity and mail-delivery boundary.

The Login → Forgot Password entry point remains available only to state this limitation:

> 此设备上的本地账户暂不支持密码重置。请使用原密码登录或联系支持人员。

The screen has no email, verification-code, or new-password input. It cannot send, simulate, verify, advance, or mutate a password-reset record.

## Client Release Scope

The iOS target no longer includes:

- third-party mail access keys or secrets;
- mail sender configuration, request signing, endpoint construction, or outbound mail transport;
- device-mail fallback or fake mail success behavior;
- client-side verification-code generation or reset-code persistence/use paths;
- login/reset diagnostics that write passwords, password hashes, reset codes, mail configuration, recipients, or raw service responses.

The existing `password_reset_codes` SQLite schema remains inert to avoid an unrelated data migration.

## Credential Disposition

An exposed third-party provider credential must be revoked or rotated outside this repository. Do not record key values in this file.

- Issue: #46
- Owner:
- Provider/key reference in approved private system:
- Revocation or rotation completed at:
- Provider activity review completed at:
- Unexpected activity found: Yes / No
- Repository-history disposition: revoke-only / history rewrite / other
- Source-removal commit:
- Verification evidence:

Removing code or history does not revoke a credential. A replacement, if needed, must be held and used only by a server-side mail boundary, never packaged into the iOS app.

## Verification Record

### Static source gate

Run the following from the repository root and expect no results:

```sh
grep -R -n -E 'EmailService|AliCloudEmail|AliCloudEmailConfig|MFMailCompose|sendPasswordResetEmail|generateSignature|debugCheckDatabase' Stronix-App/Sources Stronix-App-V1.xcodeproj

grep -n 'print(' Stronix-App/Sources/Services/Local/LocalUserService.swift Stronix-App/Sources/Views/Profile/LoginView.swift Stronix-App/Sources/Views/Auth/ForgotPasswordView.swift
```

### Automated tests

- Targeted password-reset policy tests: Pass (`LocalPasswordResetPolicyTests`)
- Full XCTest suite: Pass
- Debug build: Pass
- Release build: Pass

### Manual Release gate

- Date: Pending
- Commit: Pending
- Device or simulator: iPhone 17 Pro Simulator (Debug startup only)
- iOS version: 26.5
- Tester: Claude Code
- Result: Pending
- Console review: Pending manual reset-path verification
- Notes: Debug build installed and launched successfully. Simulator tooling available in this environment could capture startup only and could not drive the Login → Forgot Password interaction.