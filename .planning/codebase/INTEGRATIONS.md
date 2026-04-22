# External Integrations

**Analysis Date:** 2026-04-22

## APIs & External Services

**Anthropic / Claude Code OAuth:**
- Anthropic OAuth token endpoint - refreshes expired Claude Code access tokens
  - SDK/Client: native `URLSession` in `Sources/Models/AnthropicUsageService.swift`
  - Endpoint: `https://platform.claude.com/v1/oauth/token`
  - Auth: refresh token loaded from Claude Code credentials in `~/.claude/.credentials.json` or the Keychain, handled by `Sources/Models/AnthropicUsageService.swift`
- Anthropic OAuth usage endpoint - fetches current five-hour and seven-day usage windows
  - SDK/Client: native `URLSession` in `Sources/Models/AnthropicUsageService.swift`
  - Endpoint: `https://api.anthropic.com/api/oauth/usage`
  - Auth: bearer access token plus `anthropic-beta: oauth-2025-04-20` header in `Sources/Models/AnthropicUsageService.swift`

**Local Claude Code installation:**
- Claude Code credential store - supplies OAuth tokens used by the app
  - SDK/Client: `FileManager`, `Data(contentsOf:)`, and Security framework in `Sources/Models/AnthropicUsageService.swift`
  - Auth: macOS Keychain service `Claude Code-credentials` or credential file `~/.claude/.credentials.json`
- Claude Code project logs - supply per-project token breakdowns
  - SDK/Client: `FileManager` and `JSONSerialization` in `Sources/Models/TokenParser.swift`
  - Path pattern: `~/.claude/projects/*/*.jsonl`

## Data Storage

**Databases:**
- None
  - Connection: Not applicable
  - Client: Not applicable

**File Storage:**
- Local filesystem only
  - Reads Claude Code credentials from `~/.claude/.credentials.json` in `Sources/Models/AnthropicUsageService.swift`
  - Writes refreshed Claude Code credentials back to `~/.claude/.credentials.json` in `Sources/Models/AnthropicUsageService.swift`
  - Reads project usage logs from `~/.claude/projects` in `Sources/Models/TokenParser.swift`
  - Loads bundled icon assets from `Resources/` and from the packaged app bundle in `Sources/Views/MenuBarLabel.swift`

**Caching:**
- In-memory only
  - `cachedAccessToken`, `cachedRefreshToken`, `cachedFileJSON`, and `lastFetchedAt` in `Sources/Models/AnthropicUsageService.swift`
  - `cachedEntries` in `Sources/Models/UsageViewModel.swift`

## Authentication & Identity

**Auth Provider:**
- Claude Code OAuth credentials issued by Anthropic
  - Implementation: `Sources/Models/AnthropicUsageService.swift` first reads `~/.claude/.credentials.json`, then falls back to the macOS Keychain service `Claude Code-credentials`, then persists migrated/refreshed tokens back to the credential file

## Monitoring & Observability

**Error Tracking:**
- None detected

**Logs:**
- No application logging framework is present
- User-visible error states are surfaced in SwiftUI through `UsageFetchState.error(String)` in `Sources/Models/AnthropicUsageService.swift` and rendered in `Sources/Views/PopoverContentView.swift`

## CI/CD & Deployment

**Hosting:**
- Not applicable for the app itself; this is a local macOS desktop binary built from `Package.swift` and bundled by `Makefile`
- Public distribution channels documented in `README.md`:
  - Homebrew cask `younghyundev/tap/token-meter`
  - GitHub Releases ZIP download

**CI Pipeline:**
- None detected. No `.github/workflows/`, GitHub Actions files, or other CI config were found.

## Environment Configuration

**Required env vars:**
- None detected in source
- Runtime prerequisites are external state rather than env vars:
  - Claude Code login with available OAuth credentials
  - macOS filesystem access to `~/.claude/.credentials.json` and `~/.claude/projects`

**Secrets location:**
- Not stored in the repo
- Claude Code OAuth credentials are expected in:
  - macOS Keychain service `Claude Code-credentials`
  - `~/.claude/.credentials.json` outside the repository

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- HTTPS POST to `https://platform.claude.com/v1/oauth/token` from `Sources/Models/AnthropicUsageService.swift`
- HTTPS GET to `https://api.anthropic.com/api/oauth/usage` from `Sources/Models/AnthropicUsageService.swift`

## Local System Integrations

**macOS UI shell:**
- Menu bar integration uses `MenuBarExtra` in `Sources/App/TokenMeterApp.swift`
- Background-style menu bar app behavior is enabled with `LSUIElement` in `Resources/Info.plist`

**macOS preferences:**
- User preferences are persisted with `UserDefaults` and `@AppStorage` in `Sources/Models/UsageViewModel.swift` and `Sources/Models/Localization.swift`

**macOS Keychain:**
- Security framework access reads Claude Code credentials from the user Keychain in `Sources/Models/AnthropicUsageService.swift`

**Application install location:**
- `Makefile` copies the packaged app to `/Applications/TokenMeter.app`
- `README.md` documents Homebrew and manual ZIP installation paths

## Update / Distribution Integrations

**Auto-update framework:**
- None detected. No Sparkle, App Store, or in-app updater code is present.

**Manual release channels:**
- Homebrew cask installation is documented in `README.md`
- GitHub Releases ZIP distribution is documented in `README.md`
- The app is documented as not code-signed yet in `README.md`, which affects macOS launch trust behavior

---

*Integration audit: 2026-04-22*
