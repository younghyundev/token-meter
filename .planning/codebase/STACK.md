# Technology Stack

**Analysis Date:** 2026-04-22

## Languages

**Primary:**
- Swift 5.9 - entire application code in `Sources/App/`, `Sources/Models/`, and `Sources/Views/`

**Secondary:**
- XML property list - app bundle metadata in `Resources/Info.plist`
- Make - local build/install workflow in `Makefile`
- Markdown - product and distribution documentation in `README.md`

## Runtime

**Environment:**
- Native macOS app targeting macOS 14.0+ via `Package.swift` and `Resources/Info.plist`
- SwiftUI app lifecycle using `@main` in `Sources/App/TokenMeterApp.swift`

**Package Manager:**
- Swift Package Manager via `Package.swift`
- Lockfile: missing (`Package.resolved` not detected)

## Frameworks

**Core:**
- SwiftUI - menu bar UI, popover, settings, and app lifecycle in `Sources/App/TokenMeterApp.swift` and `Sources/Views/*.swift`
- Foundation - dates, files, JSON parsing, networking, timers, and URLs in `Sources/Models/*.swift`
- Combine - observable state and timer reconfiguration in `Sources/Models/UsageViewModel.swift`
- Security - Keychain access for Claude Code credential migration in `Sources/Models/AnthropicUsageService.swift`
- AppKit - menu bar image loading and app termination helpers in `Sources/Views/MenuBarLabel.swift` and `Sources/Views/PopoverContentView.swift`

**Testing:**
- Not detected. No `Tests/` directory, XCTest target, or test package configuration is present.

**Build/Dev:**
- SwiftPM executable target `TokenMeter` in `Package.swift`
- `make` commands for build/install/uninstall/run in `Makefile`
- Xcode 15+ is documented as a development prerequisite in `README.md`

## Key Dependencies

**Critical:**
- No third-party Swift packages are declared in `Package.swift`
- Apple platform frameworks are used directly:
  - `SwiftUI` for `MenuBarExtra`, views, and `@AppStorage` in `Sources/App/TokenMeterApp.swift` and `Sources/Models/Localization.swift`
  - `Foundation` for `URLSession`, `FileManager`, and JSON parsing in `Sources/Models/AnthropicUsageService.swift` and `Sources/Models/TokenParser.swift`
  - `Security` for `SecItemCopyMatching` in `Sources/Models/AnthropicUsageService.swift`
  - `AppKit` for `NSImage` and `NSApplication` in `Sources/Views/MenuBarLabel.swift` and `Sources/Views/PopoverContentView.swift`

**Infrastructure:**
- `Resources/Info.plist` defines bundle identity, version (`0.2.3`), minimum OS, icon, and LSUIElement menu-bar behavior
- `Resources/AppIcon.icns`, `Resources/menubar-icon-16.png`, and related PNG/SVG assets provide bundle and menu bar iconography
- `.build/` is the SwiftPM build output directory referenced by `Makefile`

## Configuration

**Environment:**
- No `.env` files were detected in the repository root; the app does not read environment variables from code
- Runtime configuration is stored in macOS preferences:
  - `refreshInterval` via `UserDefaults` in `Sources/Models/UsageViewModel.swift`
  - `appLanguage` via `@AppStorage` in `Sources/Models/Localization.swift`
- External credential state is loaded from Claude Code data outside the repo:
  - `~/.claude/.credentials.json` via `Sources/Models/AnthropicUsageService.swift`
  - macOS Keychain service `Claude Code-credentials` via `Sources/Models/AnthropicUsageService.swift`

**Build:**
- `Package.swift` declares a single executable target and copies `../Resources/Info.plist` into app resources
- `Makefile` assembles a macOS `.app` bundle manually under `.build/release/TokenMeter.app`
- `Resources/Info.plist` supplies bundle metadata instead of generating it from Xcode project settings

## Platform Requirements

**Development:**
- macOS 14+ from `Package.swift` and `Resources/Info.plist`
- Swift toolchain 5.9 from the `// swift-tools-version: 5.9` header in `Package.swift`
- Xcode 15+ is documented in `README.md`
- Claude Code must be installed and logged in for the app to show real data, per `README.md` and `Sources/Models/AnthropicUsageService.swift`

**Production:**
- Desktop macOS menu bar app with `LSUIElement` enabled in `Resources/Info.plist`
- Bundle identifier `com.tokenmeter.app` from `Resources/Info.plist` and `Makefile`
- Distribution artifacts are a local `.app` bundle via `Makefile` and a release ZIP/Homebrew cask path documented in `README.md`

---

*Stack analysis: 2026-04-22*
