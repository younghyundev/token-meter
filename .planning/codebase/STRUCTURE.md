# Codebase Structure

**Analysis Date:** 2026-04-22

## Directory Layout

```text
token-meter/
├── Sources/              # Single SwiftPM target source tree
│   ├── App/              # App entry point and menu bar scene setup
│   ├── Models/           # View model, services, parsers, and value types
│   └── Views/            # SwiftUI presentation components
├── Resources/            # Bundle metadata and image assets copied into the app
├── .planning/codebase/   # Generated architecture mapping documents
├── .build/               # SwiftPM build output and packaged .app artifacts
├── Package.swift         # Swift Package manifest for the executable target
├── Makefile              # Build, install, uninstall, and run workflows
├── README.md             # Product and setup documentation
└── AGENTS.md             # Agent-specific execution instructions
```

## Directory Purposes

**`Sources/App`:**
- Purpose: Hold app bootstrap code and scene composition.
- Contains: `Sources/App/TokenMeterApp.swift`.
- Key files: `Sources/App/TokenMeterApp.swift`.

**`Sources/Models`:**
- Purpose: Hold non-view logic for state, parsing, networking, persistence, and domain models.
- Contains: `Sources/Models/UsageViewModel.swift`, `Sources/Models/AnthropicUsageService.swift`, `Sources/Models/TokenParser.swift`, `Sources/Models/UsageData.swift`, `Sources/Models/Localization.swift`.
- Key files: `Sources/Models/UsageViewModel.swift`, `Sources/Models/AnthropicUsageService.swift`.

**`Sources/Views`:**
- Purpose: Hold SwiftUI view composition and small presentation helpers.
- Contains: `Sources/Views/PopoverContentView.swift`, `Sources/Views/MenuBarLabel.swift`, `Sources/Views/ProjectBreakdownView.swift`, `Sources/Views/UsageGaugeView.swift`.
- Key files: `Sources/Views/PopoverContentView.swift`, `Sources/Views/MenuBarLabel.swift`.

**`Resources`:**
- Purpose: Hold bundle metadata and image assets required by the packaged app.
- Contains: `Resources/Info.plist`, `Resources/AppIcon.icns`, `Resources/AppIcon.svg`, `Resources/claude-icon-16.png`, `Resources/claude-icon-32.png`, `Resources/menubar-icon-16.png`, `Resources/menubar-icon-32.png`.
- Key files: `Resources/Info.plist`, `Resources/AppIcon.icns`, `Resources/menubar-icon-16.png`.

**`.planning/codebase`:**
- Purpose: Hold generated reference docs for future planning and execution commands.
- Contains: `ARCHITECTURE.md`, `STRUCTURE.md`, plus any other generated codebase maps.
- Key files: `.planning/codebase/ARCHITECTURE.md`, `.planning/codebase/STRUCTURE.md`.

**`.build`:**
- Purpose: Hold generated SwiftPM outputs, intermediate metadata, and packaged release artifacts.
- Contains: `TokenMeter.app`, `TokenMeter.dSYM`, module caches, SwiftPM workspace state.
- Key files: `.build/arm64-apple-macosx/release/TokenMeter.app`, `.build/release.yaml`.

## Key File Locations

**Entry Points:**
- `Sources/App/TokenMeterApp.swift`: Runtime `@main` application entry point.
- `Package.swift`: Build-system entry point for the single executable target.
- `Makefile`: Packaging and installation entry point used outside raw SwiftPM commands.

**Configuration:**
- `Resources/Info.plist`: App bundle metadata including identifier, version, and `LSUIElement` menu bar behavior.
- `Package.swift`: Platform target (`macOS(.v14)`) and resource-copy configuration.
- `.gitignore`: Ignore rules for generated build output and local agent command artifacts.

**Core Logic:**
- `Sources/Models/UsageViewModel.swift`: App-wide state coordination and refresh scheduling.
- `Sources/Models/AnthropicUsageService.swift`: OAuth credential handling and usage API integration.
- `Sources/Models/TokenParser.swift`: Local JSONL parsing for project token breakdowns.
- `Sources/Models/UsageData.swift`: Shared value types for raw and aggregated usage data.

**Testing:**
- Not detected. No `Tests/` directory, test target, or `*.test.*` / `*.spec.*` files are present in this repository.

## Naming Conventions

**Files:**
- Use UpperCamelCase Swift filenames that match the primary type in the file, such as `Sources/Models/UsageViewModel.swift` and `Sources/Views/ProjectBreakdownView.swift`.
- Keep one main type or tightly related helper types per file, as in `Sources/Models/Localization.swift` and `Sources/Models/UsageData.swift`.

**Directories:**
- Use role-based top-level source directories under `Sources/`, specifically `App`, `Models`, and `Views`.
- Keep resource files in a flat `Resources/` directory unless a new asset set clearly benefits from grouping.

## Where to Add New Code

**New Feature:**
- Primary code: Add UI composition to `Sources/Views/` and supporting state or service logic to `Sources/Models/`.
- Tests: No established location exists. Add a new `Tests/TokenMeterTests/` target only if the repository begins adopting SwiftPM tests.

**New Component/Module:**
- Implementation: Place menu bar or popover UI components in `Sources/Views/`; place app bootstrap concerns only in `Sources/App/`.

**Utilities:**
- Shared helpers: Put non-UI helpers beside the layer they serve. Reusable parsing, formatting, or service helpers belong in `Sources/Models/`; view-only formatting helpers can stay near the owning view, as `formatTokens(_:)` does in `Sources/Views/UsageGaugeView.swift`.

## Special Directories

**`.build`:**
- Purpose: Generated SwiftPM products, intermediate state, and release bundle assembly.
- Generated: Yes
- Committed: No

**`.planning`:**
- Purpose: Planning artifacts and generated codebase maps for GSD workflows.
- Generated: Yes
- Committed: Yes

**`.claude`:**
- Purpose: Local agent settings and command artifacts.
- Generated: Mixed; `.claude/settings.local.json` is local configuration, and `.claude/commands/` is ignored by `.gitignore`.
- Committed: Partially; local command artifacts are excluded.

## Placement Guidance

- Put new app lifecycle code in `Sources/App/TokenMeterApp.swift` only when it changes scene wiring, shared object ownership, or launch behavior.
- Put new remote integrations, filesystem readers, persistence helpers, or domain transformations in `Sources/Models/` so views remain declarative.
- Put new SwiftUI sections, rows, gauges, and settings panels in `Sources/Views/`, following the existing split between container views like `Sources/Views/PopoverContentView.swift` and smaller leaf views like `Sources/Views/UsageGaugeView.swift`.
- Put new bundle metadata or icons in `Resources/` and update both `Package.swift` and `Makefile` if the packaged `.app` needs to copy them explicitly.

---

*Structure analysis: 2026-04-22*
