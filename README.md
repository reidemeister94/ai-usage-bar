<div align="center">

# AI Usage Bar

**Claude API usage tracker for your macOS menu bar.**
See your session and weekly limits at a glance. No browser tabs. No guessing.

[![CI](https://github.com/reidemeister94/ai-usage-bar/actions/workflows/ci.yml/badge.svg)](https://github.com/reidemeister94/ai-usage-bar/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-brightgreen.svg)](https://www.apple.com/macos/sonoma/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)

</div>

---

## Why AI Usage Bar?

Claude's rate limits reset on rolling windows but there's no easy way to see how close you are without opening a browser. AI Usage Bar puts your usage right in the menu bar -- always visible, always current.

- **Always visible** -- Tiny icon in your menu bar shows session and weekly usage at a glance
- **Auto-refreshing** -- Polls every 1-15 minutes (configurable), so you always know where you stand
- **Multiple auth methods** -- Works with OAuth tokens, Claude CLI, or browser cookies (automatic fallback)
- **Native & lightweight** -- Pure Swift/SwiftUI. No Electron, no web views. Launches instantly, uses minimal resources.
- **Privacy-first** -- Credentials stay on your machine. No telemetry, no analytics, no third-party services.

---

## Features

### Menu Bar Icon

A compact 18x18 icon that shows two bars:
- **Top bar** -- Session usage (5-hour rolling window)
- **Bottom hairline** -- Weekly usage (7-day rolling window)

Color-coded: green → yellow → orange → red as you approach limits.

### Popover Panel

Click the icon to see detailed stats:
- Session and weekly usage percentages with progress bars
- Countdown timers until reset (with absolute time)
- Model-specific usage (Opus, Sonnet)
- Plan tier (Free, Pro, Max, Team, Enterprise)
- Extra usage charges (in dollars, if applicable)
- Data source indicator and last refresh time

### Settings

- **Refresh interval** -- 1, 2, 5, or 15 minutes
- **Display mode** -- Show "Used" or "Remaining" percentage
- **Preferred source** -- Auto (cascade), OAuth only, CLI only, or Web only

---

## Quick Start

### Install via Homebrew

```bash
brew install --cask ai-usage-bar
```

### Or build from source

```bash
git clone https://github.com/reidemeister94/ai-usage-bar.git
cd ai-usage-bar
./Scripts/package_app.sh

# Copy to Applications
cp -r AIUsageBar.app /Applications/
```

> **First launch:** Right-click the app > Open (to bypass Gatekeeper for unsigned apps).

### Authentication

AI Usage Bar tries three methods in order, using the first that works:

| Method | How it works | Setup |
|--------|-------------|-------|
| **OAuth** | Reads tokens from Keychain or `~/.claude/.credentials.json` | Use [Claude Code](https://claude.ai/claude-code) -- tokens are created automatically |
| **Claude CLI** | Runs `claude usage --output json` | Install [Claude Code CLI](https://claude.ai/claude-code) |
| **Web cookies** | Extracts session cookies from Chrome or Safari | Just be logged into [claude.ai](https://claude.ai) |

No configuration needed in most cases -- if you use Claude Code, it works out of the box.

---

## Requirements

- **macOS 14.0+** (Sonoma)
- **Apple Silicon** (M1/M2/M3/M4)
- **Xcode 16+** (for building from source)

---

## Architecture

No external dependencies. Built entirely on system frameworks: SwiftUI, AppKit, Security, CommonCrypto, and sqlite3.

- **Single state object** -- One `AppState` with `@Observable` macro manages everything
- **Auth cascade** -- OAuth → CLI → Web cookies, with automatic fallback
- **Menu bar** -- `NSStatusItem` with custom-rendered icon
- **Strict concurrency** -- Swift 6 with `Sendable` types throughout

### Project Structure

```
Sources/AIUsageBar/
├── App/           # Entry point, AppDelegate, AppState
├── Auth/          # KeychainReader, CookieExtractor, TokenRefresher
├── Models/        # UsageData, Settings, PlanInfo
├── Services/      # UsageServiceRouter, OAuth/Web/CLI services
├── Views/         # MenuBarIcon, UsagePanelView, UsageRowView
└── Utilities/     # CountdownFormatter, PTYSession
```

---

## Development

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run tests
```

```bash
make setup-dev-env       # Install SwiftLint, SwiftFormat, pre-commit hooks
make lint                # Run SwiftLint
make format              # Run SwiftFormat
make help                # Show all targets
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for code style and PR guidelines.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Icon shows dimmed/gray | No usage data available. Check authentication method in popover. |
| "OAuth token expired" | Relaunch Claude Code to refresh the token, then restart AI Usage Bar. |
| CLI fallback not working | Ensure `claude` is installed and in your PATH. Run `claude usage` manually to verify. |
| Cookie extraction fails | Make sure you're logged into claude.ai in Chrome or Safari. Chrome must be fully quit first. |
| App won't open | Right-click > Open on first launch to bypass Gatekeeper. |
| High CPU usage | Increase the refresh interval in the popover settings (try 5 or 15 minutes). |

---

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, commit conventions, and how to submit a PR.

---

## License

MIT -- see [LICENSE](LICENSE).
