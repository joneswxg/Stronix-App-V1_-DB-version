# Stronix App

This context defines the project language used when discussing the Stronix App product and its staged remediation work.

## Language

**Gradual Remediation**:
An approach that improves the existing app in phases while preserving current business flows, local data, and reusable assets.
_Avoid_: Rewrite, rebuild, new project

**Comprehensive Remediation**:
A complete remediation program covering data safety, architecture boundaries, state management, UI consistency, resources, testing, and delivery quality across the existing app.
_Avoid_: First-round fix, stopgap cleanup

**Phased Delivery**:
A delivery approach where the remediation program has a complete target state but is executed in ordered increments with verification gates between phases.
_Avoid_: Big-bang refactor, all-at-once rewrite

**Risk-Layered Roadmap**:
A remediation roadmap ordered by cross-cutting technical risk first, then applied within each business area.
_Avoid_: Feature-only roadmap, page-by-page cleanup

**Template Plan**:
A built-in training plan supplied by the app as reusable starting material and managed independently from user-owned plans.
_Avoid_: System user plan, user_id 0 plan

**User Plan**:
A training plan owned and edited by a real app user, whose data must be preserved across app and database upgrades.
_Avoid_: Template copy, system plan

**Local SQLite Scope**:
The database remediation scope focused on the iOS app's bundled and Documents SQLite databases, excluding Supabase migration work.
_Avoid_: Supabase migration scope, cloud database remediation

**Plural Table Names**:
The long-term database naming convention where tables use plural nouns such as users, actions, training_plans, and template_plans.
_Avoid_: Mixed singular/plural table names

**Layered App Flow**:
The target app dependency flow where Views delegate intent to ViewModels, ViewModels call UseCases, UseCases depend on Repository protocols, and repositories adapt local services or SQLite clients.
_Avoid_: View-to-database flow, View-to-service flow

**Repository Adapter**:
A transitional repository implementation that wraps an existing local service while exposing a cleaner protocol to ViewModels and UseCases.
_Avoid_: Direct singleton service dependency

**Risk-Based Testing**:
A testing strategy that adds verification where the current phase has meaningful data, behavior, or regression risk instead of optimizing for blanket coverage first.
_Avoid_: Coverage-first testing, test-last cleanup

**Design System Stage**:
The formal remediation stage that standardizes app colors, typography, spacing, radii, reusable components, dark mode, accessibility, and localization.
_Avoid_: Opportunistic UI cleanup, cosmetic-only pass

**Engineering Hygiene Stage**:
The formal remediation stage that cleans repository noise, resource manifests, file permissions, icon assets, stale configuration, and build-maintenance issues.
_Avoid_: UI cleanup, incidental housekeeping

**Security and Privacy Stage**:
The formal remediation stage that reviews local credential handling, client-held service secrets, authentication flows, and privacy-sensitive user data.
_Avoid_: Optional security cleanup, post-release hardening
