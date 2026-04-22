---
phase: 02-codex-experience
plan: 02
subsystem: ui
tags: [swiftui, macos, codex, claude, swiftpm]
requires:
  - phase: 02-01
    provides: provider-scoped UsageViewModel state and Codex status snapshot contracts
provides:
  - segmented Claude/Codex selector inside usage mode
  - dedicated Codex session status card with typed states
  - provider-scoped project filter and empty/login/unavailable project copy
affects: [popover, localization, usage-view-model, tests]
tech-stack:
  added: []
  patterns: [provider-aware popover composition, typed project availability rendering]
key-files:
  created: [Sources/Views/CodexStatusCardView.swift, Tests/TokenMeterTests/PopoverContentViewTests.swift]
  modified: [Sources/Views/PopoverContentView.swift, Sources/Views/ProjectBreakdownView.swift, Sources/Models/Localization.swift, Sources/Models/UsageViewModel.swift, Tests/TokenMeterTests/UsageViewModelTests.swift]
key-decisions:
  - "Refresh and project period changes stay scoped to the currently visible provider tab."
  - "Project empty, login-required, and unavailable states render from typed availability data instead of localized string parsing."
patterns-established:
  - "Use a segmented Picker in usage mode only for provider switching."
  - "Compose Codex session UI as a dedicated card while keeping Claude gauges unchanged."
requirements-completed: [NAV-01, CPRJ-03, CDEX-01, CDEX-02, CDEX-03, CPRJ-02]
duration: 16m
completed: 2026-04-22
---

# Phase 2 Plan 2: Codex Experience Summary

**Popover 안에 Claude/Codex segmented selector, Codex 상태 카드, provider별 프로젝트 필터와 상태 문구를 추가해 Codex 탭 경험을 완성했다**

## Performance

- **Duration:** 16 min
- **Started:** 2026-04-22T08:20:00Z
- **Completed:** 2026-04-22T08:36:28Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- usage 모드 상단에 `Claude` / `Codex` segmented selector를 추가하고, Codex 탭에서 dedicated status card를 렌더링했다.
- 프로젝트 섹션을 typed availability 기반으로 바꿔 empty, login-required, unavailable 상태를 provider-specific copy로 구분했다.
- refresh와 period 변경을 현재 선택 provider에만 적용하도록 맞추고, 관련 회귀를 테스트로 고정했다.

## Task Commits

Each task was committed atomically:

1. **Task 1: Provider selector와 Codex status card를 popover usage shell에 배치** - `f3b53a3` (`feat`)
2. **Task 2: Provider-specific project filter와 empty/unavailable copy를 연결** - `6dbf20c` (`feat`)

## Files Created/Modified
- `Sources/Views/CodexStatusCardView.swift` - Codex session snapshot을 usage, availability, login-required, unavailable 카드로 렌더링
- `Sources/Views/PopoverContentView.swift` - provider selector, provider-aware project binding, Codex refresh label/help 추가
- `Sources/Views/ProjectBreakdownView.swift` - typed availability에 따라 rows, empty, login-required, unavailable 분기 렌더링
- `Sources/Models/Localization.swift` - provider tab, Codex 상태, period label, refresh 접근성 copy 추가
- `Sources/Models/UsageViewModel.swift` - visible-provider만 refresh하고 탭 전환 시 provider 상태를 로드하도록 조정
- `Tests/TokenMeterTests/PopoverContentViewTests.swift` - popover shell 기본 provider, period copy, provider switch load 검증
- `Tests/TokenMeterTests/UsageViewModelTests.swift` - current-provider refresh semantics를 새 truth에 맞게 갱신

## Decisions Made
- provider 탭은 settings 모드와 분리된 usage 모드 내부에만 배치해 기존 shell 구조를 유지했다.
- Codex 프로젝트 섹션은 string parsing 대신 `ProviderAvailability`를 직접 받아 상태를 분기하도록 구성했다.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Codex 탭 refresh가 Claude usage fetch까지 호출하던 동작 수정**
- **Found during:** Task 2
- **Issue:** `forceRefresh()`와 `refresh()`가 항상 Claude usage service를 호출해 "현재 보이는 provider만 refresh" truth를 위반했다.
- **Fix:** `UsageViewModel`에서 Claude 선택 시에만 usage fetch를 수행하고, provider-scoped state refresh만 유지했다.
- **Files modified:** `Sources/Models/UsageViewModel.swift`, `Tests/TokenMeterTests/UsageViewModelTests.swift`
- **Verification:** `swift test --filter PopoverContentViewTests`, `swift test`
- **Committed in:** `6dbf20c`

**2. [Rule 2 - Missing Critical] provider 전환 직후 해당 provider 상태를 즉시 로드하도록 보강**
- **Found during:** Task 2
- **Issue:** 탭을 Codex로 바꿔도 새 provider 상태를 읽지 않아 기본 empty/login placeholder가 남을 수 있었다.
- **Fix:** `selectedProvider` 변경 시 provider-scoped 로드를 트리거하고, 전환 동작을 전용 테스트로 고정했다.
- **Files modified:** `Sources/Models/UsageViewModel.swift`, `Tests/TokenMeterTests/PopoverContentViewTests.swift`
- **Verification:** `swift test --filter PopoverContentViewTests`, `swift test`
- **Committed in:** `6dbf20c`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical)
**Impact on plan:** 둘 다 계획의 must-have truth를 충족하기 위한 수정이며 범위 확장은 없었다.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 2의 사용자 가시 기능은 완료되었고, 다음 Phase는 Claude 회귀 검증과 외부 사용자 setup confidence에 집중할 수 있다.
- 메뉴 바 라벨은 의도적으로 건드리지 않았으므로 SAFE-01 검증은 Phase 3에서 실제 UI 회귀 관점으로 이어가면 된다.

## Self-Check
PASSED
- Summary file exists: `.planning/phases/02-codex-experience/02-codex-experience-02-SUMMARY.md`
- Task commits verified in git history: `f3b53a3`, `6dbf20c`

---
*Phase: 02-codex-experience*
*Completed: 2026-04-22*
