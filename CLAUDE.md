# AI Usage Bar -- Development Guide

## Project Overview

Native macOS menu bar app (Swift 6 / SwiftUI) that displays Claude API usage statistics in real-time. Shows session (5-hour), weekly (7-day), and model-specific rate limit usage with automatic refresh. Fetches data from the `https://api.anthropic.com/api/oauth/usage` endpoint using Claude Code's OAuth credentials.

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
- `Resources/` -- AppIcon.icns, Info.plist
- `Scripts/` -- package_app.sh (creates signed .app bundle)
- `Formula/` -- Homebrew cask formula
- `Package.swift` -- SPM manifest (Swift 6.0, macOS 14+)

### Key Files

| File | Role |
|------|------|
| `AppState.swift` | Centralized state management (`@Observable`), adaptive backoff on 429 |
| `AppDelegate.swift` | Menu bar setup, NSStatusItem, icon rendering |
| `AIUsageBarApp.swift` | `@main` entry point |
| `UsageService.swift` | `UsageService` protocol (fetchUsage, isAvailable) |
| `UsageServiceRouter.swift` | Routes to OAuth → CLI → Web with cascade fallback |
| `OAuthUsageService.swift` | Anthropic OAuth API integration, 429 handling via token refresh |
| `CLIUsageService.swift` | Claude CLI interactive `/status` fallback runner |
| `WebUsageService.swift` | claude.ai web API via session cookies |
| `KeychainReader.swift` | OAuth token reading: credentials file → app cache → Keychain (one-time prompt) |
| `CookieExtractor.swift` | Chrome (AES-128 decryption) & Safari cookie extraction |
| `TokenRefresher.swift` | OAuth token refresh logic, persists refreshed tokens to app cache |
| `UsageData.swift` | Data structures for usage windows (session, weekly, model-specific, cowork, oauth apps) |
| `Settings.swift` | RefreshInterval, PreferredSource, CookieSource, UsageError enums |
| `PlanInfo.swift` | Plan tier information |
| `MenuBarIcon.swift` | Renders 18x18 icon with usage bars |
| `UsagePanelView.swift` | Main popover UI with settings |
| `UsageRowView.swift` | Individual usage row component |
| `CountdownFormatter.swift` | Reset countdown timer formatting |
| `PTYSession.swift` | Runs CLI commands with PTY and timeout |

## Architecture & Conventions

- **No external dependencies** -- only system frameworks (SwiftUI, AppKit, Security, CommonCrypto, sqlite3)
- **State pattern** -- single `AppState` with `@Observable` macro
- **Authentication cascade** -- OAuth (credentials file → app cache → Keychain) → Claude CLI → Web cookies
- **Credential caching** -- after first Keychain read, credentials are persisted to `~/Library/Application Support/AIUsageBar/cached_credentials.json` so the Keychain password is never prompted again
- **Rate limit handling** -- 429 from `/api/oauth/usage` triggers token refresh (resets per-token rate limit window), with exponential backoff in polling interval
- **Menu bar** -- `NSStatusItem` with custom-rendered 18x18 icon
- **Popover** -- `NSPopover` with SwiftUI content
- **Concurrency** -- Swift 6 strict concurrency, `Sendable` types, async/await throughout
- **Configuration** -- `UserDefaults` for refresh interval (5m/10m/15m/30m, default 5m), display mode, preferred source
- **140-character line length limit**
- **4-space indentation**
- **Trailing commas enforced**

## OAuth Usage API

The primary data source is `GET https://api.anthropic.com/api/oauth/usage` with headers:
- `Authorization: Bearer <token>` (from Claude Code credentials)
- `anthropic-beta: oauth-2025-04-20`

**Rate limiting**: The endpoint aggressively rate-limits (~5 requests per access token). On 429, the app refreshes the OAuth token to get a fresh rate limit window. If that also fails, it backs off exponentially (up to 1 hour).

Response format:
```json
{
  "five_hour": {"utilization": 40.0, "resets_at": "2026-03-06T02:00:00+00:00"},
  "seven_day": {"utilization": 94.0, "resets_at": "2026-03-06T12:00:00+00:00"},
  "seven_day_opus": null,
  "seven_day_sonnet": {"utilization": 4.0, "resets_at": "..."},
  "seven_day_cowork": null,
  "seven_day_oauth_apps": null,
  "extra_usage": {"is_enabled": true, "monthly_limit": 0, "used_credits": 0.0, "utilization": null}
}
```

- `utilization` is 0-100 (percent), divide by 100 for display
- All `seven_day_*` windows can be null
- `extra_usage.monthly_limit` and `used_credits` are in cents
- Credentials read order: `~/.claude/.credentials.json` → `~/Library/Application Support/AIUsageBar/cached_credentials.json` → macOS Keychain (`"Claude Code-credentials"` / `"claudeAiOauth"`)

## Platform

- macOS 14.0+ (Sonoma)
- Apple Silicon (arm64)
- Swift 6.0+
