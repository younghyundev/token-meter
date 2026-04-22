# Architecture

**Analysis Date:** 2026-04-22

## Pattern Overview

**Overall:** Single-target SwiftUI menu bar application with lightweight MVVM-style coordination.

**Key Characteristics:**
- `Sources/App/TokenMeterApp.swift` is the only runtime entry point and creates a single long-lived `UsageViewModel`.
- `Sources/Models/UsageViewModel.swift` acts as the orchestration boundary between UI state, network usage fetching, local log parsing, and persisted settings.
- `Sources/Views/*.swift` stay presentation-focused and consume derived state from the view model instead of performing I/O directly.

## Layers

**Application Shell:**
- Purpose: Boot the menu bar scene and attach the shared state object to the popover and label views.
- Location: `Sources/App`
- Contains: `TokenMeterApp`, the `MenuBarExtra` scene, and the macOS 15 content-margin compatibility modifier in `Sources/App/TokenMeterApp.swift`.
- Depends on: `SwiftUI`, `UsageViewModel`, `PopoverContentView`, `MenuBarLabel`.
- Used by: Swift runtime via `@main`.

**State and Orchestration:**
- Purpose: Hold published UI state, schedule refreshes, persist settings, and rebuild project aggregates after each refresh.
- Location: `Sources/Models/UsageViewModel.swift`
- Contains: `UsageViewModel`, refresh timer lifecycle, `UserDefaults`-backed settings, cached parsed entries, and computed percentages exposed to the UI.
- Depends on: `AnthropicUsageService`, `TokenParser`, `Combine`, `SwiftUI`, `Foundation`.
- Used by: `Sources/App/TokenMeterApp.swift`, `Sources/Views/MenuBarLabel.swift`, `Sources/Views/PopoverContentView.swift`.

**Domain Models:**
- Purpose: Define the value types used across parsing, aggregation, and rendering.
- Location: `Sources/Models/UsageData.swift`
- Contains: `ProjectPeriod`, `TokenUsageEntry`, and `ProjectUsage`.
- Depends on: `Foundation`.
- Used by: `Sources/Models/UsageViewModel.swift`, `Sources/Models/TokenParser.swift`, `Sources/Views/ProjectBreakdownView.swift`.

**Remote Usage Service:**
- Purpose: Read Claude credentials, refresh OAuth tokens, call Anthropic usage endpoints, and normalize API responses into app-friendly usage windows.
- Location: `Sources/Models/AnthropicUsageService.swift`
- Contains: `AnthropicUsageService`, `UsageWindow`, `ClaudeUsageData`, `UsageFetchState`.
- Depends on: `Foundation`, `Security`, `URLSession`, the local credentials file at `~/.claude/.credentials.json`, and Keychain service `Claude Code-credentials`.
- Used by: `Sources/Models/UsageViewModel.swift`.

**Local Log Parsing:**
- Purpose: Scan Claude project JSONL logs and turn message usage payloads into token entries for project-level aggregation.
- Location: `Sources/Models/TokenParser.swift`
- Contains: `TokenParser` and JSONL line-by-line parsing logic for `~/.claude/projects`.
- Depends on: `Foundation`, local filesystem access.
- Used by: `Sources/Models/UsageViewModel.swift`.

**Localization State:**
- Purpose: Keep app language in shared storage and provide string lookup for views.
- Location: `Sources/Models/Localization.swift`
- Contains: `AppLanguage`, `LocalizationManager`, and global `L(_:)`.
- Depends on: `SwiftUI` and `@AppStorage`.
- Used by: `Sources/Views/PopoverContentView.swift`, `Sources/Views/ProjectBreakdownView.swift`.

**Presentation Layer:**
- Purpose: Render the menu bar percentage, usage gauges, project breakdown, settings panel, and footer actions.
- Location: `Sources/Views`
- Contains: `PopoverContentView`, `MenuBarLabel`, `ProjectBreakdownView`, `UsageGaugeView`.
- Depends on: Published state from `UsageViewModel`, localization via `L(_:)`, and asset resources copied into the app bundle.
- Used by: `Sources/App/TokenMeterApp.swift`.

## Data Flow

**App Launch and Initial Refresh:**

1. `Sources/App/TokenMeterApp.swift` constructs `@StateObject private var viewModel = UsageViewModel()`.
2. The `MenuBarExtra` popover runs `.task { viewModel.start() }`, which loads credentials, aligns fetch intervals, performs the first refresh, and starts a repeating `Timer` in `Sources/Models/UsageViewModel.swift`.
3. `Sources/Views/MenuBarLabel.swift` and `Sources/Views/PopoverContentView.swift` react to published state changes from the same `UsageViewModel`.

**Refresh Cycle:**

1. `UsageViewModel.refresh()` awaits `usageService.fetchUsage()` in `Sources/Models/AnthropicUsageService.swift`.
2. `AnthropicUsageService` loads cached credentials, optionally refreshes the OAuth token, requests `https://api.anthropic.com/api/oauth/usage`, and stores normalized usage windows in `usageData`.
3. `UsageViewModel` runs `TokenParser.parseAll()` in a detached task, caches the resulting `[TokenUsageEntry]`, rebuilds grouped `ProjectUsage` values, and updates `lastRefreshed`.

**Project Breakdown Rebuild:**

1. `cachedEntries` are filtered by `projectPeriod` in `Sources/Models/UsageViewModel.swift`.
2. Entries are grouped by `projectPath`, reduced into `ProjectUsage`, and sorted descending by `totalTokens`.
3. `Sources/Views/ProjectBreakdownView.swift` renders the first eight rows with segmented filtering bound directly to `viewModel.projectPeriod`.

**State Management:**
- Use a single `@StateObject` in `Sources/App/TokenMeterApp.swift` as the app-wide source of truth.
- Keep ephemeral UI state local to a view, such as `currentTab` in `Sources/Views/PopoverContentView.swift`.
- Persist user preferences with `UserDefaults` or `@AppStorage`, as shown in `Sources/Models/UsageViewModel.swift` and `Sources/Models/Localization.swift`.

## Key Abstractions

**UsageViewModel:**
- Purpose: Central coordinator for all mutable app state and refresh behavior.
- Examples: `Sources/Models/UsageViewModel.swift`
- Pattern: `@MainActor` observable object that exposes read-mostly computed properties to SwiftUI.

**AnthropicUsageService:**
- Purpose: Encapsulate all credential, auth-refresh, rate-limit, and remote fetch behavior.
- Examples: `Sources/Models/AnthropicUsageService.swift`
- Pattern: Service object with internal caching and a normalized `UsageFetchState`.

**TokenParser:**
- Purpose: Convert Claude JSONL logs into `TokenUsageEntry` values without giving file I/O responsibilities to views.
- Examples: `Sources/Models/TokenParser.swift`
- Pattern: Stateless-ish parser object instantiated once by the view model and executed off the main actor.

**ProjectUsage / TokenUsageEntry:**
- Purpose: Separate raw token records from aggregated project-level display models.
- Examples: `Sources/Models/UsageData.swift`
- Pattern: Small `struct` value types with computed token totals.

**PopoverContentView:**
- Purpose: Compose the app’s main UI sections and route user actions back to the view model.
- Examples: `Sources/Views/PopoverContentView.swift`
- Pattern: Container view with private computed subviews for header, usage, settings, and footer sections.

## Entry Points

**Application Entry Point:**
- Location: `Sources/App/TokenMeterApp.swift`
- Triggers: macOS launches the executable target `TokenMeter` defined in `Package.swift`.
- Responsibilities: Build the single menu bar scene, inject the shared `UsageViewModel`, and start the refresh loop from the popover task.

**Build and Packaging Entry Point:**
- Location: `Package.swift`
- Triggers: `swift build`, `swift run`, and `make build`.
- Responsibilities: Define the single executable target rooted at `Sources` and copy `Resources/Info.plist` into bundle resources.

**Distribution Assembly Entry Point:**
- Location: `Makefile`
- Triggers: `make build`, `make install`, `make run`, `make uninstall`.
- Responsibilities: Wrap SwiftPM output into `TokenMeter.app`, copy icons and `Info.plist`, and install or run the packaged app.

## Error Handling

**Strategy:** Represent remote fetch status as explicit state and degrade gracefully when credentials, auth, or network operations fail.

**Patterns:**
- `Sources/Models/AnthropicUsageService.swift` maps failure conditions to `UsageFetchState.error(String)` instead of throwing through the UI.
- `Sources/Models/UsageViewModel.swift` keeps previous parsed data in `cachedEntries` and only rebuilds view state after successful parsing work completes.
- `Sources/Views/PopoverContentView.swift` surfaces API errors inline in the session section and shows a dedicated login-required empty state when `hasCredentials` is false.

## Cross-Cutting Concerns

**Logging:** Not detected in authored source files under `Sources`; the app currently relies on UI-visible error state instead of explicit logs.

**Validation:** Response parsing is defensive and optional-cast based in `Sources/Models/AnthropicUsageService.swift` and `Sources/Models/TokenParser.swift`; invalid or incomplete payloads are skipped rather than causing a crash.

**Authentication:** `Sources/Models/AnthropicUsageService.swift` owns all auth concerns, preferring `~/.claude/.credentials.json`, falling back to Keychain migration, and retrying once after token refresh on `401` or `403`.

---

*Architecture analysis: 2026-04-22*
