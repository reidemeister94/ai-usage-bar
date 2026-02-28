# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


### Added
- Menu bar icon with session (5-hour) and weekly (7-day) usage bars
- Popover panel with detailed usage statistics
- OAuth authentication via Keychain / Claude Code credentials
- Claude CLI fallback (`claude usage --output json`)
- Web cookie extraction (Chrome with AES decryption, Safari) as last resort
- Model-specific usage tracking (Opus, Sonnet)
- Plan tier display (Free, Pro, Max, Team, Enterprise)
- Toggle between "Used" and "Remaining" percentage display
- Configurable refresh intervals (1, 2, 5, 15 minutes)
- Countdown timers with absolute reset times
- Extra usage charges tracking (in dollars)
- Auto-refresh with configurable polling
- Homebrew cask formula for distribution
- App bundle packaging script with ad-hoc code signing

## v1.1.1 (2026-02-28)

### Fix

- improvements

## v1.1.0 (2026-02-28)

### Feat

- improvements

## v1.0.0 (2026-02-28)

### Feat

- improvements
- codebase

### Fix

- minor fixes
- minor improvements
- use xcode 16
- minor fixes
- minor fixes
