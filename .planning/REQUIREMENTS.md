# Requirements: Token Meter Codex Expansion

**Defined:** 2026-04-22
**Core Value:** Developers can glance at the menu bar and immediately understand their remaining coding-agent capacity and which projects are consuming it.

## v1 Requirements

### Navigation

- [x] **NAV-01
**: User can switch between `Claude` and `Codex` tabs in the popover

### Codex Session Status

- [x] **CDEX-01
**: User can see Codex session usage, remaining-session state, or equivalent current-session availability in the Codex tab
- [x] **CDEX-02
**: User can manually refresh Codex session status from the popover
- [x] **CDEX-03
**: User sees a clear unavailable or login-required state when Codex session status cannot be retrieved

### Codex Project Breakdown

- [x] **CPRJ-01**: User can see Codex token usage grouped by project path
- [x] **CPRJ-02
**: User can filter Codex project usage by `1 day`, `7 days`, and `all`
- [x] **CPRJ-03
**: User sees projects sorted by highest Codex token usage first

### Stability

- [ ] **SAFE-01**: Claude tab continues to show existing session, weekly, and project breakdown behavior without regression
- [x] **SAFE-02**: App does not expose raw Codex auth tokens or sensitive local artifacts in the UI or logs
- [x] **SAFE-03**: Missing or malformed Codex local data does not crash the app

### Distribution

- [ ] **DIST-01**: Another macOS user with Codex installed and signed in can use the Codex feature without project-specific custom setup

## v2 Requirements

### Expanded Analytics

- **ANLY-01**: User can see combined multi-provider summary totals across Claude and Codex
- **ANLY-02**: User can compare provider usage trends over longer time windows

### Provider Platform

- **PLUG-01**: App supports adding future providers through a generalized provider plug-in architecture

## Out of Scope

| Feature | Reason |
|---------|--------|
| Cross-platform desktop support | Existing product is macOS-only and current value does not require broader platform work |
| Unified billing/cost dashboard | User asked for session status and project token visibility, not spend reporting |
| Raw session-log inspection UI | Operationally noisy and creates avoidable security/privacy risk |
| Generic provider marketplace | Premature abstraction before validating Codex support |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| NAV-01 | Phase 2 | Complete |
| CDEX-01 | Phase 2 | Complete |
| CDEX-02 | Phase 2 | Complete |
| CDEX-03 | Phase 2 | Complete |
| CPRJ-01 | Phase 1 | Complete |
| CPRJ-02 | Phase 2 | Complete |
| CPRJ-03 | Phase 2 | Complete |
| SAFE-01 | Phase 3 | Pending |
| SAFE-02 | Phase 1 | Complete |
| SAFE-03 | Phase 1 | Complete |
| DIST-01 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0

---
*Requirements defined: 2026-04-22*
*Last updated: 2026-04-22 after plan 02-02 execution*
