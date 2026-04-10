# Token Meter

<p align="center">
  <img src="Resources/claude-icon.svg" width="128" height="128" alt="Token Meter">
</p>

<p align="center">
  <strong>macOS menu bar app for monitoring Claude Code token usage in real-time</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

---

## What is Token Meter?

Token Meter lives in your macOS menu bar and shows your Claude Code API usage at a glance. It reads your Claude Code OAuth credentials and displays:

- **Session usage (5-hour window)** - Current usage percentage with color-coded gauge
- **Weekly usage (7-day window)** - Weekly consumption tracking
- **Per-project token breakdown** - See which projects consume the most tokens
- **Reset countdown** - Time remaining until your session limit resets

No additional API keys needed - it uses your existing Claude Code login.

## Screenshots

| Menu Bar | Usage View | Project Breakdown |
|----------|-----------|-------------------|
| Shows current session % | Color-coded usage gauges | Token usage per project |

## Installation

### Homebrew (Recommended)

```bash
brew install --cask younghyundev/tap/token-meter
```

### Troubleshooting: "App is damaged" error

If you see a "damaged" warning when opening the app, run:

```bash
xattr -cr /Applications/TokenMeter.app
```

This is because the app is not yet code-signed with an Apple Developer certificate. The Homebrew cask handles this automatically.

### Build from Source

Requires **Xcode 15+** and **macOS 14 (Sonoma)** or later.

```bash
git clone https://github.com/younghyundev/token-meter.git
cd token-meter
make install
```

This builds the app and copies it to `/Applications/TokenMeter.app`.

### Manual

Download the latest `.zip` from [Releases](https://github.com/younghyundev/token-meter/releases), extract, and drag `TokenMeter.app` to your Applications folder.

## Prerequisites

- **macOS 14.0 (Sonoma)** or later
- **Claude Code** must be installed and logged in (`claude` CLI)
  - Token Meter reads credentials from Claude Code's Keychain entry or `~/.claude/.credentials.json`

## Usage

1. Launch Token Meter - it appears as a Claude icon with a percentage in the menu bar
2. Click the icon to see detailed usage:
   - **Session (5h)**: Your current 5-hour rolling window usage
   - **Weekly (7d)**: Your 7-day rolling window usage
   - **Projects**: Token breakdown by project (filterable by 1 day / 7 days / all time)
3. Click the gear icon to adjust settings:
   - **Language**: Korean / English
   - **Update interval**: 1min / 5min / 10min / 30min / 60min

## How It Works

Token Meter uses two data sources:

1. **Anthropic OAuth Usage API** - Fetches your real-time session and weekly utilization percentages using your Claude Code OAuth token
2. **Local JSONL logs** - Parses `~/.claude/projects/*/**.jsonl` files to calculate per-project token usage breakdown

The app automatically refreshes token data if the OAuth token expires, using the refresh token flow.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Language | Korean | UI language (Korean / English) |
| Update interval | 60 seconds | How often to fetch usage data |

Settings are persisted in UserDefaults.

## Uninstall

```bash
# If installed via Homebrew
brew uninstall --cask token-meter

# If installed via make
make uninstall

# Or manually
rm -rf /Applications/TokenMeter.app
```

## Tech Stack

- **Swift 5.9** / **SwiftUI**
- **macOS 14+** (MenuBarExtra API)
- Keychain Services for secure credential access
- No third-party dependencies

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
