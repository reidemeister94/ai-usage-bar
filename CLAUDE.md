# AI Usage Bar -- Development Guide

## Project Overview

Native macOS menu bar app (Swift 6 / SwiftUI) that displays Claude API usage statistics in real-time. Shows session (5-hour) and weekly (7-day) rate limit usage with automatic refresh.

## Build Commands

```bash
swift build              # Debug build
swift build -c release   # Release build
swift test               # Run tests
./Scripts/package_app.sh # Build .app bundle (release + codesign)
```

## Developer Tooling

```bash
make setup-dev-env   # Install SwiftLint, SwiftFormat, pre-commit hooks
make lint            # Run SwiftLint
make lint-fix        # Run SwiftLint with auto-fix
make format          # Run SwiftFormat (auto-fix)
make help            # Show all targets
```

- **Pre-commit** runs trailing-whitespace, end-of-file-fixer, SwiftLint, SwiftFormat on every commit
- **Commitizen** enforces conventional commit messages (commit-msg hook)
- **SwiftLint** config: `.swiftlint.yml` (line_length 140, includes Sources/)
- **SwiftFormat** config: `.swiftformat` (4-space indent, maxwidth 140, trailing commas)

## Project Structure

- `Sources/AIUsageBar/` -- single executable target with all source code
- `Sources/AIUsageBar/App/` -- @main entry point, AppDelegate, AppState
- `Sources/AIUsageBar/Auth/` -- KeychainReader, CookieExtractor, TokenRefresher
- `Sources/AIUsageBar/Models/` -- UsageData, Settings, PlanInfo
- `Sources/AIUsageBar/Services/` -- UsageServiceRouter, OAuth/Web/CLI services
- `Sources/AIUsageBar/Views/` -- MenuBarIcon, UsagePanelView, UsageRowView
- `Sources/AIUsageBar/Utilities/` -- CountdownFormatter, PTYSession
- `Resources/` -- Info.plist
- `Scripts/` -- package_app.sh (creates signed .app bundle)
- `Formula/` -- Homebrew cask formula
- `Package.swift` -- SPM manifest (Swift 6.0, macOS 14+)

### Key Files

| File | Role |
|------|------|
| `AppState.swift` | Centralized state management (`@Observable` macro) |
| `AppDelegate.swift` | Menu bar setup, NSStatusItem, icon rendering |
| `AIUsageBarApp.swift` | `@main` entry point |
| `UsageServiceRouter.swift` | Routes to OAuth → CLI → Web with cascade fallback |
| `OAuthUsageService.swift` | Anthropic OAuth API integration |
| `CLIUsageService.swift` | `claude usage --output json` subprocess runner |
| `WebUsageService.swift` | claude.ai web API via session cookies |
| `KeychainReader.swift` | OAuth token reading from Keychain / ~/.claude/.credentials.json |
| `CookieExtractor.swift` | Chrome (AES-128 decryption) & Safari cookie extraction |
| `TokenRefresher.swift` | OAuth token refresh logic |
| `UsageData.swift` | Data structures for usage windows (session, weekly) |
| `Settings.swift` | RefreshInterval, PreferredSource, DisplayMode enums |
| `PlanInfo.swift` | Plan tier information |
| `MenuBarIcon.swift` | Renders 18x18 icon with usage bars |
| `UsagePanelView.swift` | Main popover UI with settings |
| `UsageRowView.swift` | Individual usage row component |
| `CountdownFormatter.swift` | Reset countdown timer formatting |
| `PTYSession.swift` | Runs CLI commands with PTY and timeout |

## Architecture & Conventions

- **No external dependencies** -- only system frameworks (SwiftUI, AppKit, Security, CommonCrypto, sqlite3)
- **State pattern** -- single `AppState` with `@Observable` macro
- **Authentication cascade** -- OAuth (Keychain) → Claude CLI → Web cookies (automatic fallback)
- **Menu bar** -- `NSStatusItem` with custom-rendered 18x18 icon
- **Popover** -- `NSPopover` with SwiftUI content
- **Concurrency** -- Swift 6 strict concurrency, `Sendable` types, async/await throughout
- **Configuration** -- `UserDefaults` for refresh interval, display mode, preferred source
- **140-character line length limit**
- **4-space indentation**
- **Trailing commas enforced**

## Platform

- macOS 14.0+ (Sonoma)
- Apple Silicon (arm64)
- Swift 6.0+
