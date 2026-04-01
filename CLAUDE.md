# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

hops is a macOS URL router app (bundle ID: `dev.hops.app`). It registers as the default browser for `http`/`https` schemes, intercepts clicked URLs via Apple Events, matches them against rules in `~/.hops.toml`, strips tracking params, resolves Chrome profile names to directories, and opens the URL in the matched browser/app. When launched without a URL (Finder/Dock), it shows a SwiftUI config window.

## Build & test

```bash
swift test                                          # run all tests
swift test --filter HopsTests.URLCleanerTests       # run one test class
swift build -c release                              # release build
make install                                        # build + copy to /Applications/hops.app + register with Launch Services
make clean                                          # remove app bundle
```

CI builds a universal binary: `swift build -c release --arch arm64 --arch x86_64`

Requires Swift 5.9+ / macOS 13+.

## Architecture

Two targets in `Package.swift`:

- **HopsCore** (library, `Sources/HopsCore/`) — all testable logic, no AppKit/SwiftUI:
  - `HopsConfig` — parses/serializes `~/.hops.toml` (via TOMLKit), routes URLs to a `BrowserTarget` using first-match-wins handler evaluation
  - `URLMatcher` — `URLMatchable` protocol with `GlobMatcher` (glob→regex on host+path) and `HostnameMatcher` (exact + regex on hostname)
  - `URLCleaner` — strips `utm_*`, `uta_*`, `fbclid`, `gclid` query params
  - `ChromeProfile` — reads Chrome's `Local State` JSON to resolve display name → profile directory
  - `Launcher` — shells out to `/usr/bin/open` with the right `--profile-directory` flag, then activates the target app via `osascript`

- **hops** (executable, `Sources/hops/`) — SwiftUI app shell:
  - `HopsApp` — `@main` entry point with `NSApplicationDelegateAdaptor`
  - `AppDelegate` — registers Apple Event handler in `applicationWillFinishLaunching`, routes URLs or shows config UI
  - `Sources/hops/UI/` — `ConfigWindow`, `HandlerEditor`, `DefaultBrowserStatus` (SwiftUI views for the config-mode GUI)

Tests are in `Tests/` — one test file per HopsCore module (no UI tests).

## Key design details

- **First match wins**: handlers in `~/.hops.toml` are evaluated top-to-bottom; the first matching handler determines the target. If none match, `[default]` is used.
- **Activation policy switch**: when handling a URL, the app sets `.accessory` activation policy so hops doesn't appear in the Dock or steal focus from the target browser.
- **Chrome profile resolution**: `ChromeProfile` reads `~/Library/Application Support/Google/Chrome/Local State` and maps the user-friendly display name to the actual `Profile N` directory name.
- **Process lifecycle**: after routing a URL, the app calls `NSApp.terminate(nil)` — hops is not a long-running process.
