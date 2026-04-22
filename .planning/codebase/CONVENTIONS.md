# Conventions

**Analysis Date:** 2026-04-22

## Code Style

**General Style:**
- Swift source files use direct imports with minimal layering, typically `Foundation`, `SwiftUI`, `Combine`, `Security`, or `AppKit` depending on the file in `Sources/`.
- Types are small and file-scoped by responsibility, with one primary type per file in `Sources/App/`, `Sources/Models/`, and `Sources/Views/`.
- Access control is mostly left at the default internal level; encapsulation is handled with `private` properties and helper methods inside a file, as seen in `Sources/Models/UsageViewModel.swift` and `Sources/Views/PopoverContentView.swift`.
- Code favors computed properties and small helper methods over protocol-heavy abstractions or extension-driven decomposition.

**Formatting Patterns:**
- Section markers use `// MARK: - ...` heavily in larger files such as `Sources/Models/UsageViewModel.swift`, `Sources/Models/AnthropicUsageService.swift`, and `Sources/Views/PopoverContentView.swift`.
- Inline comments are sparse and mostly reserved for intent or platform notes, such as the menu bar content margin compatibility note in `Sources/App/TokenMeterApp.swift`.
- Doc comments appear selectively where background-thread or migration behavior needs emphasis, for example in `Sources/Models/TokenParser.swift` and `Sources/Models/AnthropicUsageService.swift`.
- Multiline Swift literals and chained modifiers are formatted vertically with trailing commas in collections and dictionaries.

## Naming

**Types:**
- View types use noun-based SwiftUI names ending in `View`, such as `PopoverContentView`, `ProjectBreakdownView`, and `UsageGaugeView` in `Sources/Views/`.
- Model and service types describe their role directly, such as `UsageViewModel`, `AnthropicUsageService`, `TokenUsageEntry`, and `ProjectUsage` in `Sources/Models/`.
- Enums use concise domain names like `ProjectPeriod`, `PopoverTab`, `UsageFetchState`, and `AppLanguage`.

**Properties and Methods:**
- Mutable state uses lowerCamelCase names with explicit intent, for example `refreshInterval`, `lastRefreshed`, `projectPeriod`, `cachedEntries`, and `hasCredentials` in `Sources/Models/UsageViewModel.swift`.
- Async or side-effecting methods use verb names like `start()`, `stop()`, `refresh()`, `forceRefresh()`, `fetchUsage()`, `loadCredentials()`, and `refreshAccessToken()`.
- Helpers are often prefixed with a scope hint such as `rebuildProjects()`, `parseJSONLInto(...)`, `humanizeProjectPath(...)`, and `colorForProject(...)`.

**UserDefaults and Localization Keys:**
- Preference keys are raw string literals rather than centralized constants, currently `refreshInterval` in `Sources/Models/UsageViewModel.swift` and `appLanguage` in `Sources/Models/Localization.swift`.
- Localization keys follow a dotted namespace pattern like `session.title`, `footer.updated`, and `settings.interval` in `Sources/Models/Localization.swift`.

## Architectural Conventions

**State Management:**
- Shared app state lives in a single `@StateObject` created at the app entry in `Sources/App/TokenMeterApp.swift`.
- Views receive state through `@ObservedObject` or `@Binding` rather than constructing services directly, as seen across `Sources/Views/MenuBarLabel.swift`, `Sources/Views/PopoverContentView.swift`, and `Sources/Views/ProjectBreakdownView.swift`.
- The main view model is marked `@MainActor`, and background work is explicitly detached for file parsing in `Sources/Models/UsageViewModel.swift`.

**Responsibility Split:**
- `Sources/Models/UsageViewModel.swift` coordinates refresh timing, persistence, parsing, and display-ready aggregation.
- `Sources/Models/AnthropicUsageService.swift` owns credential access, token refresh, rate limiting, and API response normalization.
- `Sources/Models/TokenParser.swift` owns local file scanning and JSONL parsing.
- `Sources/Views/*.swift` stay presentation-oriented and mostly rely on already-derived values.

**Value Modeling:**
- Domain data is represented with lightweight `struct` types in `Sources/Models/UsageData.swift`.
- Aggregate and raw record models are separated: `TokenUsageEntry` stores parsed log records, while `ProjectUsage` stores display-friendly grouped data.

## UI Conventions

**Composition:**
- Container views are broken into private computed subviews instead of separate files when the UI is small enough, especially in `Sources/Views/PopoverContentView.swift`.
- Reusable visual elements are extracted only when they have clear standalone value, such as `UsageGaugeView` and the private `ProjectRow` in `Sources/Views/ProjectBreakdownView.swift`.

**Sizing and Typography:**
- The UI uses explicit `.font(.system(...))` sizing rather than custom font tokens, throughout `Sources/Views/MenuBarLabel.swift`, `Sources/Views/PopoverContentView.swift`, `Sources/Views/ProjectBreakdownView.swift`, and `Sources/Views/UsageGaugeView.swift`.
- Popover layout uses fixed widths and compact spacing tuned for menu bar usage, such as `.frame(width: 300)` in `Sources/Views/PopoverContentView.swift`.

**Localization:**
- Strings are localized through the global `L(_:)` lookup function from `Sources/Models/Localization.swift` rather than `LocalizedStringKey` or `.strings` bundles.
- Some display strings remain hard-coded in English, including `"1min"` to `"60min"` and token suffixes in `Sources/Views/PopoverContentView.swift` and `Sources/Views/UsageGaugeView.swift`.

## Concurrency and Async Conventions

**Main Actor Usage:**
- UI-facing observable objects are marked `@MainActor`, including `UsageViewModel` and `LocalizationManager`.
- Network fetches are awaited directly from the main-actor view model, while CPU and file parsing work is pushed into `Task.detached` in `Sources/Models/UsageViewModel.swift`.

**Caching and Refreshing:**
- The code favors in-memory caching over recomputation, with `cachedEntries`, cached OAuth tokens, and `lastFetchedAt` in `Sources/Models/UsageViewModel.swift` and `Sources/Models/AnthropicUsageService.swift`.
- Interval changes are observed reactively through Combine in `Sources/Models/UsageViewModel.swift`.

## Error Handling Conventions

**Style:**
- File and JSON parsing usually fail softly through `try?`, optional casts, and guard-return patterns in `Sources/Models/AnthropicUsageService.swift` and `Sources/Models/TokenParser.swift`.
- Recoverable network/auth problems are converted into `UsageFetchState.error(String)` rather than propagated as thrown errors.
- Missing credentials degrade into an alternate UI state in `Sources/Views/PopoverContentView.swift` instead of blocking app launch.

**Tradeoff:**
- The app prioritizes resilience and a simple UI path over strongly typed error propagation, at the cost of reduced diagnosability and limited observability.

## Dependency Conventions

**External Dependencies:**
- No third-party packages are used; integrations stay within Apple frameworks plus Anthropic and Claude Code data sources described in `Package.swift`, `README.md`, and `Sources/Models/AnthropicUsageService.swift`.

**Resource Access:**
- Bundle assets are loaded defensively with fallback paths in `Sources/Views/MenuBarLabel.swift`.
- External user data is read directly from `~/.claude/.credentials.json` and `~/.claude/projects` in `Sources/Models/AnthropicUsageService.swift` and `Sources/Models/TokenParser.swift`.

## Notable Deviations and Inconsistencies

- Comments mix English and Korean in `Sources/Models/AnthropicUsageService.swift`, which is understandable but not fully standardized.
- Some user-facing text is localized through `L(_:)`, while some display strings remain inline English literals in views.
- Preference keys are duplicated as raw strings rather than centralized constants, increasing typo risk as settings grow.
- There is no formatter or linter configuration in the repository root, so the current style is convention-based rather than tool-enforced.

## Practical Guidance For Future Changes

- Put new I/O or integration code in `Sources/Models/` or a new service file, not directly inside a SwiftUI view.
- Keep view files focused on rendering and lightweight event wiring, following `Sources/Views/PopoverContentView.swift` and `Sources/Views/ProjectBreakdownView.swift`.
- Continue using small value types for parsed and aggregated data, similar to `Sources/Models/UsageData.swift`.
- If settings expand, centralize `UserDefaults` keys and consider replacing the global `L(_:)` function with a more structured localization layer.

---

*Conventions analysis: 2026-04-22*
