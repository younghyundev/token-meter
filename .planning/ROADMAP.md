# Roadmap: Token Meter Codex Expansion

**Date:** 2026-04-22
**Project:** Token Meter
**Granularity:** Coarse
**Requirements mapped:** 10 / 10

## Summary

Three coarse phases deliver Codex support to the existing app without breaking Claude behavior. Phase 1 builds the provider and parsing foundation, Phase 2 delivers the user-visible Codex experience, and Phase 3 hardens the app for external users and release confidence.

| Phase | Name | Goal | Requirements | Success Criteria |
|-------|------|------|--------------|------------------|
| 1 | Codex Data Foundation | Add provider-ready domain and Codex local-data ingestion | CPRJ-01, SAFE-02, SAFE-03 | 3 |
| 2 | Codex Experience | Ship the Codex tab, session status, and polished project breakdown | NAV-01, CDEX-01, CDEX-02, CDEX-03, CPRJ-02, CPRJ-03 | 4 |
| 3 | Regression and Ship Readiness | Prove Claude stability and external-user usability | SAFE-01, DIST-01 | 3 |

## Phase Details

### Phase 1: Codex Data Foundation

**Goal:** The app can safely read Codex local artifacts and produce provider-ready project usage data without exposing sensitive information.

**Requirements:** `CPRJ-01`, `SAFE-02`, `SAFE-03`

**Plans:** 3 plans

Plans:
- [x] `01-01-PLAN.md` - Add the SwiftPM test target and provider-neutral project usage contracts
- [x] `01-02-PLAN.md` - Implement Codex SQLite, rollout, and auth-state adapters
- [x] `01-03-PLAN.md` - Compose the Codex repository and wire `UsageViewModel` to the repository seam

**Success Criteria:**
1. The codebase contains Codex-specific parsing logic for local session artifacts and/or SQLite thread metadata.
2. Codex project token totals can be derived for at least one real local workspace path.
3. Missing or malformed Codex data produces a recoverable state rather than a crash or credential leak.

**UI hint:** no

### Phase 2: Codex Experience

**Goal:** Users can switch to a Codex tab and see current Codex session state plus project usage with the same lightweight interaction model as the existing Claude experience.

**Requirements:** `NAV-01`, `CDEX-01`, `CDEX-02`, `CDEX-03`, `CPRJ-02`, `CPRJ-03`

**Plans:** 2 plans

Plans:
- [x] `02-01-PLAN.md` - Define availability-first Codex status contracts and provider-scoped view-model state
- [x] `02-02-PLAN.md` - Build the Codex popover UI with provider tabs, status card, and provider-specific project filters

**Success Criteria:**
1. The popover exposes separate `Claude` and `Codex` tabs.
2. The Codex tab shows session usage or a clear unavailable/login-required state.
3. The Codex tab shows project usage rows with `1 day`, `7 days`, and `all` filtering.
4. Codex project rows are sorted by highest token usage first.

**UI hint:** yes

### Phase 3: Regression and Ship Readiness

**Goal:** Codex support is stable enough for distribution, and Claude behavior remains intact for current users.

**Requirements:** `SAFE-01`, `DIST-01`

**Success Criteria:**
1. Manual verification confirms Claude tab behavior still matches current shipped expectations.
2. Manual verification confirms a second macOS user setup can access Codex data after signing in locally.
3. README, error messaging, and any setup guidance are updated to reflect Codex support and known limitations.

**UI hint:** no

## Coverage Check

- All v1 requirements map to exactly one phase.
- No phase exists without user-visible or risk-reduction value.
- The highest technical uncertainty, Codex data access, is handled before UI completion.

---
*Roadmap created: 2026-04-22*
