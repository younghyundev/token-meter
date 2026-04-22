# Testing

**Analysis Date:** 2026-04-22

## Current State

**Automated Test Setup:**
- No `Tests/` directory exists in the repository root.
- `Package.swift` declares only a single executable target and no `testTarget`.
- No XCTest, Swift Testing, snapshot testing, or UI test configuration was detected in the current codebase.

**Observed Verification Mode:**
- The project currently appears to rely on manual verification through local app runs via `make run`, `make install`, and direct menu bar interaction described in `README.md` and `Makefile`.
- Runtime correctness is partially guarded by defensive parsing and error-state UI, but not by committed automated regression coverage.

## Testable Units

**High-Value Pure or Mostly Pure Logic:**
- `Sources/Models/TokenParser.swift`
  - JSONL line parsing behavior
  - date parsing with fractional and non-fractional ISO 8601 timestamps
  - token aggregation eligibility rules
- `Sources/Models/UsageData.swift`
  - `TokenUsageEntry.totalTokens`
  - `TokenUsageEntry.billableTokens`
- `Sources/Models/UsageViewModel.swift`
  - project filtering by `ProjectPeriod`
  - grouping and sorting behavior in `rebuildProjects()`
  - project path display normalization in `humanizeProjectPath(_:)`
- `Sources/Views/UsageGaugeView.swift`
  - formatting behavior in `formatTokens(_:)`
  - percentage-to-color threshold logic in `barColor`

**Integration-Heavy Logic Needing Seams or Test Doubles:**
- `Sources/Models/AnthropicUsageService.swift`
  - credential loading from `~/.claude/.credentials.json`
  - Keychain migration via `SecItemCopyMatching`
  - OAuth refresh request flow
  - API fetch retry behavior on `401`, `403`, and `429`
- `Sources/Models/UsageViewModel.swift`
  - refresh loop coordination across `AnthropicUsageService`, `TokenParser`, `Timer`, and `UserDefaults`

## Current Gaps

**Missing Coverage Areas:**
- No regression protection for Anthropic API response parsing in `Sources/Models/AnthropicUsageService.swift`.
- No automated checks for malformed or large JSONL inputs in `Sources/Models/TokenParser.swift`.
- No tests around the timer and refresh interval behavior in `Sources/Models/UsageViewModel.swift`.
- No validation that localization keys are complete across `.korean` and `.english` dictionaries in `Sources/Models/Localization.swift`.
- No UI tests for menu bar label rendering, popover settings toggling, or empty/error states in `Sources/Views/`.
- No packaging smoke test to verify the `.app` bundle assembly performed by `Makefile`.

## Manual Testing Surface

**Existing Manual Flows Worth Preserving:**
- Launch the app on macOS 14+ and confirm `MenuBarExtra` renders from `Sources/App/TokenMeterApp.swift`.
- Verify login-required behavior by running without `~/.claude/.credentials.json` and ensuring `Sources/Views/PopoverContentView.swift` shows the no-credentials state.
- Verify successful fetch behavior with valid Claude credentials and confirm the menu bar percentage updates in `Sources/Views/MenuBarLabel.swift`.
- Change the update interval in settings and confirm the refresh cadence changes via `Sources/Models/UsageViewModel.swift`.
- Switch language settings and confirm localized strings update through `Sources/Models/Localization.swift`.
- Inspect project breakdown filtering for 1 day, 7 days, and all time via `Sources/Views/ProjectBreakdownView.swift`.
- Force API failures or rate limits and confirm error-state rendering in `Sources/Views/PopoverContentView.swift`.

## Recommended Automated Test Strategy

**Phase 1: Low-Friction Unit Tests**
- Add a test target in `Package.swift` for parser, formatter, and aggregation logic.
- Extract line parsing from `Sources/Models/TokenParser.swift` into a function that accepts `Data` so fixtures can be tested without touching the real `~/.claude/projects` directory.
- Extract project aggregation from `Sources/Models/UsageViewModel.swift` into a helper that can be tested without `@MainActor` view-model setup.
- Add focused tests for `formatTokens(_:)` and token total calculations from `Sources/Views/UsageGaugeView.swift` and `Sources/Models/UsageData.swift`.

**Phase 2: Service-Level Tests**
- Introduce injectable seams for `URLSession`, file loading, and current time in `Sources/Models/AnthropicUsageService.swift`.
- Add fixtures covering successful usage payloads, `401` refresh flows, `429` retry-after handling, and invalid JSON.
- Replace direct `UserDefaults.standard` usage in `Sources/Models/UsageViewModel.swift` with an injectable store to make setting behavior deterministic in tests.

**Phase 3: UI and End-to-End Confidence**
- Add SwiftUI or UI automation tests for the popover’s major states: loading, credential-missing, loaded, and error.
- Add a packaging smoke test in CI that runs `swift build` and optionally validates `make build` on macOS runners.

## Likely Test Fixtures

**Useful Fixtures To Add:**
- Sample OAuth usage API responses mirroring the structure parsed in `Sources/Models/AnthropicUsageService.swift`.
- JSONL log samples with:
  - valid usage entries
  - blank lines
  - malformed JSON
  - entries with zero billable usage
  - mixed timestamp formats
- Localization key snapshot fixtures to ensure both language dictionaries cover the same keys in `Sources/Models/Localization.swift`.

## Testability Risks

- `Sources/Models/AnthropicUsageService.swift` hard-codes file paths, Keychain access, `URLSession`, and OAuth URLs, which makes isolated tests harder without refactoring.
- `Sources/Models/UsageViewModel.swift` constructs `AnthropicUsageService` and `TokenParser` internally instead of accepting dependencies.
- `Sources/Models/TokenParser.swift` always targets the real home-directory Claude logs and does not expose a fixture-friendly initializer.
- Some logic worth testing is hidden inside private methods and computed properties, which will push future tests toward refactoring or broader black-box coverage.

## Practical Next Step

- Start by adding a small automated test target around `TokenUsageEntry`, `formatTokens(_:)`, and extracted parser/aggregation helpers. That gives immediate regression value without forcing a large architecture rewrite.

---

*Testing analysis: 2026-04-22*
