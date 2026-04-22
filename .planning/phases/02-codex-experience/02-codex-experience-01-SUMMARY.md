---
phase: 02-codex-experience
plan: 01
subsystem: ui
tags: [swift, swiftui, mvvm, codex, claude]
requires:
  - phase: 01-codex-data-foundation
    provides: tested Codex SQLite aggregation and repository seams for project usage
provides:
  - availability-first Codex session status repository
  - provider-scoped UsageViewModel state for Claude and Codex
  - independent Claude/Codex project period selection and refresh routing
affects: [popover, project-breakdown, localization]
tech-stack:
  added: []
  patterns: [availability-first provider state, provider-scoped view-model accessors]
key-files:
  created: [Sources/Models/Provider/CodexStatusRepository.swift, Tests/TokenMeterTests/CodexStatusRepositoryTests.swift]
  modified: [Sources/Models/UsageData.swift, Sources/Models/Codex/CodexProjectUsageRepository.swift, Sources/Models/Provider/ProjectUsageRepository.swift, Sources/Models/UsageViewModel.swift, Tests/TokenMeterTests/CodexProjectUsageRepositoryTests.swift, Tests/TokenMeterTests/UsageViewModelTests.swift]
key-decisions:
  - "Codex status defaults to availability-first auth mapping because no stable authenticated usage metric source exists yet."
  - "UsageViewModel keeps compatibility-facing `projects` and `projectPeriod` while storing Claude and Codex state separately underneath."
patterns-established:
  - "Provider availability is carried as typed state (`available`, `loginRequired`, `unavailable`) instead of inferred strings."
  - "Visible-provider refresh updates only the currently selected provider while preserving the other provider's cached state."
requirements-completed: [CDEX-01, CDEX-02, CDEX-03, CPRJ-02]
duration: 8 min
completed: 2026-04-22
---

# Phase 2 Plan 1: Codex Experience Summary

**Codex availability-first status contracts and provider-scoped UsageViewModel state for independent Claude/Codex periods**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-22T08:09:30Z
- **Completed:** 2026-04-22T08:17:43Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Added `CodexStatusRepository` with explicit `availabilityOnly`, `loginRequired`, and `unavailable` contract coverage.
- Updated Codex project snapshots so authenticated empty ranges stay `.available` while auth failures map to `.loginRequired`.
- Reworked `UsageViewModel` to publish provider-specific period, availability, project, and Codex status surfaces without direct view parsing.

## Task Commits

Each task was committed atomically:

1. **Task 1: Codex status and project availability contracts 정의** - `4472dd0` (feat)
2. **Task 2: Provider-scoped period and refresh orchestration을 `UsageViewModel`에 연결** - `af10420` (feat)

## Files Created/Modified
- `Sources/Models/Provider/CodexStatusRepository.swift` - Codex auth-to-status mapping for availability-first session state.
- `Sources/Models/UsageData.swift` - Added `ProviderAvailability.loginRequired`.
- `Sources/Models/Codex/CodexProjectUsageRepository.swift` - Differentiates login-required, empty authenticated ranges, and unavailable data.
- `Sources/Models/Provider/ProjectUsageRepository.swift` - Added legacy aggregation handling for `loginRequired`.
- `Sources/Models/UsageViewModel.swift` - Split provider-specific project periods, caches, availability, and Codex status refresh flow.
- `Tests/TokenMeterTests/CodexProjectUsageRepositoryTests.swift` - Covers login-required and authenticated-empty Codex project cases.
- `Tests/TokenMeterTests/CodexStatusRepositoryTests.swift` - Covers missing, malformed, and authenticated Codex status mapping.
- `Tests/TokenMeterTests/UsageViewModelTests.swift` - Covers provider-scoped periods, visible-provider refresh, and empty Codex state publishing.

## Decisions Made
- Kept the Codex session contract availability-first, because research confirmed no stable authenticated Codex quota metric source is available yet.
- Preserved existing `UsageViewModel.projects` and `projectPeriod` surfaces as compatibility wrappers while routing new state through explicit provider accessors.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated legacy aggregation for new availability enum**
- **Found during:** Task 1 (Codex status and project availability contracts 정의)
- **Issue:** Adding `ProviderAvailability.loginRequired` made `ProjectUsageAggregation` non-exhaustive and blocked compilation.
- **Fix:** Added a `loginRequired` branch to `ProjectUsageAggregation` so legacy aggregation paths continue to compile while new provider-specific state is consumed directly.
- **Files modified:** `Sources/Models/Provider/ProjectUsageRepository.swift`
- **Verification:** `swift test --filter CodexStatusRepositoryTests`, `swift test --filter CodexProjectUsageRepositoryTests`, `swift test --filter UsageViewModelTests`
- **Committed in:** `4472dd0`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** The auto-fix was required to keep existing aggregation callers compiling after the new availability contract landed.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Provider-scoped state is ready for the Phase 2 popover UI to bind directly to Claude/Codex tabs and Codex status cards.
- No blocker from this plan; next work can focus on the SwiftUI layer and localization wiring.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/02-codex-experience/02-codex-experience-01-SUMMARY.md`.
- Verified task commits `4472dd0` and `af10420` in git history.

---
*Phase: 02-codex-experience*
*Completed: 2026-04-22*
