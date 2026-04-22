# Codebase Concerns

**Analysis Date:** 2026-04-22

## Tech Debt

**Anthropic usage service is a multi-responsibility hotspot:**
- Issue: `AnthropicUsageService` combines credential discovery, Keychain migration, OAuth refresh, HTTP transport, rate-limit handling, and response parsing in one file.
- Files: `Sources/Models/AnthropicUsageService.swift`
- Impact: Changes to Claude credential storage or Anthropic response shapes require editing a single fragile class with broad blast radius. Failures in one concern are hard to isolate or test.
- Fix approach: Split `Sources/Models/AnthropicUsageService.swift` into credential storage, OAuth client, and usage-response decoding components with typed models instead of `[String: Any]`.

**View model owns both polling and analytics recomputation:**
- Issue: `UsageViewModel` owns timer setup, refresh orchestration, local log parsing, and project aggregation.
- Files: `Sources/Models/UsageViewModel.swift`
- Impact: Polling behavior, parsing cost, and UI state are tightly coupled, which makes future changes like manual refresh semantics, background refresh, or caching hard to implement safely.
- Fix approach: Extract a refresh coordinator and a project-usage repository so the view model only maps domain state into published UI state.

**Local data parsing depends on untyped JSONL internals:**
- Issue: `TokenParser` parses raw JSONL lines with ad hoc dictionary access and default fallback values.
- Files: `Sources/Models/TokenParser.swift`, `Sources/Models/UsageData.swift`
- Impact: Schema drift in Claude log files can silently degrade project analytics instead of failing loudly, and there is no compatibility layer for old/new formats.
- Fix approach: Introduce versioned `Decodable` parsing for the JSONL message subset and record parse failures separately from valid usage entries.

## Known Bugs

**Refresh button silently ignores clicks during the force-refresh cooldown:**
- Symptoms: Pressing the refresh button can do nothing for up to 60 seconds without any UI feedback.
- Files: `Sources/Views/PopoverContentView.swift`, `Sources/Models/UsageViewModel.swift`, `Sources/Models/AnthropicUsageService.swift`
- Trigger: Click the refresh button in `Sources/Views/PopoverContentView.swift` after a recent fetch; `fetchUsage(force: true)` exits early when `elapsed < minForceInterval`.
- Workaround: Wait at least 60 seconds before pressing refresh again.

**“Last updated” advances even when remote data did not refresh successfully:**
- Symptoms: The footer can report a recent update time after network failure, auth failure, rate limiting, or a skipped fetch.
- Files: `Sources/Models/UsageViewModel.swift`, `Sources/Models/AnthropicUsageService.swift`, `Sources/Views/PopoverContentView.swift`
- Trigger: Any call to `refresh()` or `forceRefresh()` updates `lastRefreshed` after parsing local logs, regardless of whether `usageService.fetchUsage()` loaded fresh API data.
- Workaround: Read the inline error text in the session section instead of trusting the footer timestamp.

## Security Considerations

**Keychain credentials are downgraded into a plaintext file:**
- Risk: `migrateFromKeychain()` reads the Claude Code Keychain entry and writes the credential payload to `~/.claude/.credentials.json`, then later refreshes overwrite that same file.
- Files: `Sources/Models/AnthropicUsageService.swift`, `README.md`
- Current mitigation: The app first tries the existing Claude file and uses Keychain only as a fallback source.
- Recommendations: Keep secrets in Keychain, or at minimum enforce file permissions and avoid automatic migration of tokens into plaintext storage.

**OAuth requests rely on bearer tokens without additional hardening or auditing:**
- Risk: Access tokens and refresh tokens are kept in memory and written back to disk through `saveCredentials(...)`, while failures are swallowed with `try?`.
- Files: `Sources/Models/AnthropicUsageService.swift`
- Current mitigation: Network timeouts are configured and requests are limited to Anthropic HTTPS endpoints.
- Recommendations: Replace `try?` writes with explicit error handling, add file-permission validation, and log non-secret failure states so credential persistence problems are visible.

**Unsigned distribution creates user trust and tampering risk:**
- Risk: The README instructs users to clear quarantine on damaged builds because the app is not code-signed.
- Files: `README.md`, `Makefile`
- Current mitigation: Homebrew packaging is described as the preferred install path.
- Recommendations: Add code signing and notarization to the release path so users do not have to bypass Gatekeeper manually.

## Performance Bottlenecks

**Every refresh rescans all local Claude project logs from scratch:**
- Problem: `refresh()` and `forceRefresh()` always call `TokenParser.parseAll()`, which enumerates every project directory and every `.jsonl` file under `~/.claude/projects`.
- Files: `Sources/Models/UsageViewModel.swift`, `Sources/Models/TokenParser.swift`, `README.md`
- Cause: There is no incremental parsing, no persisted cursor, and no file modification cache.
- Improvement path: Track file offsets or modification dates per log file and only parse appended content since the last successful scan.

**Each JSONL file is loaded fully into memory before line parsing:**
- Problem: `parseJSONLInto(url:project:entries:)` calls `Data(contentsOf:)` for every file.
- Files: `Sources/Models/TokenParser.swift`
- Cause: Parsing is optimized to avoid a second string copy, but it still requires the entire file payload in memory.
- Improvement path: Stream files with `FileHandle` or an input stream so large Claude history files do not spike memory usage.

**Project aggregation reprocesses all cached entries on every period switch and refresh:**
- Problem: `rebuildProjects()` filters, groups, and reduces the full cached dataset for each UI period change.
- Files: `Sources/Models/UsageViewModel.swift`, `Sources/Views/ProjectBreakdownView.swift`
- Cause: Aggregates are derived on demand with no precomputed buckets for day/week/all.
- Improvement path: Maintain pre-aggregated summaries keyed by period or incrementally update project totals as new entries arrive.

## Fragile Areas

**Claude integration depends on undocumented local file paths and response schemas:**
- Files: `Sources/Models/AnthropicUsageService.swift`, `Sources/Models/TokenParser.swift`, `README.md`
- Why fragile: The app assumes Claude credentials live at `~/.claude/.credentials.json` or in the `Claude Code-credentials` Keychain item, and that project logs live under `~/.claude/projects` with specific JSON keys.
- Safe modification: Treat these integrations as unstable adapters. Isolate path discovery and response decoding before changing UI or refresh behavior.
- Test coverage: No automated tests verify credential discovery or JSONL compatibility across Claude Code versions.

**Usage API contract is pinned with hard-coded protocol details:**
- Files: `Sources/Models/AnthropicUsageService.swift`
- Why fragile: The client depends on a fixed OAuth client ID, a beta header value (`oauth-2025-04-20`), and untyped JSON keys like `five_hour`, `seven_day`, and `extra_usage`.
- Safe modification: Centralize endpoint constants and add contract tests or fixture-based parsing checks before changing request headers or response handling.
- Test coverage: No fixtures or network contract tests are present anywhere under `Sources/` or `Tests/`.

**App lifetime and polling are tied to a single SwiftUI task:**
- Files: `Sources/App/TokenMeterApp.swift`, `Sources/Models/UsageViewModel.swift`
- Why fragile: `viewModel.start()` is launched from the popover content task, and polling state lives on one long-lived view model instance with no explicit app lifecycle hooks beyond timer invalidation.
- Safe modification: Move refresh start/stop ownership to an app-level coordinator before adding sleep/wake handling, background behavior, or multiple windows.
- Test coverage: No lifecycle tests or manual smoke-test scripts are documented.

## Scaling Limits

**Local usage analytics scale linearly with Claude history size:**
- Current capacity: Each refresh walks the full `~/.claude/projects` tree and reparses every `.jsonl` file.
- Limit: As Claude history grows, menu bar refresh cost and memory usage grow proportionally, which will eventually make a 60-second default interval too expensive.
- Scaling path: Add incremental indexing, cap history windows at parse time, and cache aggregated project totals on disk.

**UI only surfaces the top eight projects:**
- Current capacity: `ProjectBreakdownView` renders `projects.prefix(8)`.
- Limit: Heavy multi-project users lose visibility into the long tail of project consumption.
- Scaling path: Add scrolling, drill-down navigation, or a secondary detail window for the full project list.

## Dependencies at Risk

**Undocumented Anthropic and Claude Code interfaces:**
- Risk: The app has no third-party package dependency risk, but its core functionality depends on private or weakly documented Anthropic usage endpoints and Claude Code storage conventions.
- Impact: If Anthropic changes OAuth headers, endpoint behavior, local credential layout, or JSONL schemas, both usage gauges and project breakdowns can fail simultaneously.
- Migration plan: Wrap Anthropic/Claude integration behind versioned adapters and keep fixture samples for each supported external format.

## Missing Critical Features

**No automated test suite:**
- Problem: The repository contains no `Tests/` directory, no XCTest targets, and no CI test runner.
- Blocks: Safe refactoring of credential handling, response parsing, log parsing, and refresh timing behavior.

**No observability for field failures:**
- Problem: Fetch, migration, and parse failures are only reflected as transient UI strings or silent fallbacks.
- Blocks: Diagnosing real-world issues like schema drift, permission errors, rate limiting, and token persistence failures.

**No release hardening pipeline:**
- Problem: Build/install steps in `Makefile` assemble and copy the app bundle locally, while the README still documents unsigned-app friction.
- Blocks: Reliable distribution, user trust, and safe automatic updates.

## Test Coverage Gaps

**Credential migration and refresh flow are untested:**
- What's not tested: File-first credential loading, Keychain migration, refresh-token rotation, 401/403 retry flow, and rate-limit backoff.
- Files: `Sources/Models/AnthropicUsageService.swift`
- Risk: Auth regressions can lock users out or overwrite good credentials without warning.
- Priority: High

**JSONL parsing and aggregation are untested:**
- What's not tested: Parsing mixed-validity log files, timestamp formats, large files, project grouping, and period filtering.
- Files: `Sources/Models/TokenParser.swift`, `Sources/Models/UsageViewModel.swift`, `Sources/Models/UsageData.swift`
- Risk: Project usage numbers can drift silently as Claude log formats evolve.
- Priority: High

**UI interaction states are untested:**
- What's not tested: No-credential state, loading state, error rendering, refresh-button behavior, settings persistence, and top-eight project truncation.
- Files: `Sources/Views/PopoverContentView.swift`, `Sources/Views/ProjectBreakdownView.swift`, `Sources/Views/UsageGaugeView.swift`, `Sources/Models/Localization.swift`
- Risk: Basic menu bar workflows can regress without detection.
- Priority: Medium

---

*Concerns audit: 2026-04-22*
