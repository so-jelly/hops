# hops — SwiftUI Rewrite Design Spec

## Summary

Rewrite the grouter URL router as a pure Swift/SwiftUI macOS app called **hops**. Replaces the Go core + Swift wrapper two-binary architecture with a single SwiftUI app that handles both URL routing (via Apple Events) and configuration (via a native GUI).

## Goals

- Single binary, single language (Swift), single build system (SPM)
- Structured config UI with handler reordering, app browsing, and live default browser status
- First-run prompt to set hops as default browser
- Feature parity with grouter: glob/hostname/regex matching, UTM stripping, Chrome profile resolution, app activation

## Non-Goals

- Menu bar mode (future consideration)
- Sync/cloud config
- Non-macOS platforms

## Architecture

### Dual-Mode App

hops is a standard SwiftUI macOS app (`@main`). It operates in two modes:

1. **URL mode:** Launched via `kAEGetURL` Apple Event (user clicked a link). Route the URL silently — no window, no UI. Exit after routing.
2. **Config mode:** Launched directly from Finder/Dock (no Apple Event). Show the config window.

Mode detection: Register the Apple Event handler in `applicationWillFinishLaunching`. Set a flag when a URL event arrives. In `applicationDidFinishLaunching`, if the flag is not set, open the config window.

### File Structure

```
so-jelly/hops/
├── Sources/
│   ├── HopsApp.swift              ← @main, Apple Event handler, mode detection
│   ├── Config/
│   │   ├── HopsConfig.swift       ← TOML model + parser + serializer
│   │   └── ChromeProfile.swift    ← Chrome Local State → profile directory resolver
│   ├── Routing/
│   │   ├── URLMatcher.swift       ← Glob + hostname + regex matching
│   │   ├── URLCleaner.swift       ← Strip tracking params
│   │   └── Router.swift           ← Match URL → launch browser → activate
│   └── UI/
│       ├── ConfigWindow.swift     ← Main window: status + default browser + handler list
│       ├── HandlerEditor.swift    ← Add/edit handler sheet
│       └── DefaultBrowserStatus.swift ← Check/prompt for default browser
├── Tests/
│   ├── URLMatcherTests.swift
│   ├── URLCleanerTests.swift
│   ├── HopsConfigTests.swift
│   └── ChromeProfileTests.swift
├── Info.plist
├── Package.swift
├── Makefile
├── LICENSE
└── README.md
```

### Dependencies

- **TOMLKit** (or similar SPM package) for TOML parsing/serialization — avoids writing a custom parser
- No other external dependencies

## Routing Engine

Ported from grouter's Go implementation. Behavior is identical.

### URL Matching

Three matcher types, evaluated per-handler:

- **GlobMatcher:** Pattern like `github.com/my-org/*` matched against `host + path`. Uses `fnmatch` or equivalent.
- **HostnameMatcher:** Exact hostname string match (e.g., `localhost`).
- **HostnameRegexpMatcher:** Regex pattern against hostname (e.g., `.*\.local$`).

Handlers are evaluated top-to-bottom. First match wins. If no handler matches, the default browser target is used.

### URL Cleaning

Before opening any URL, strip tracking query parameters:

- Prefixed: `utm_*`, `uta_*`
- Exact: `fbclid`, `gclid`

Implemented via `URLComponents` — parse query items, filter, reassemble.

### Chrome Profile Resolution

Read `~/Library/Application Support/Google/Chrome/Local State` (JSON). Extract `profile.info_cache` mapping. Match the user-provided display name (e.g., "Work") to the directory name (e.g., "Profile 2").

### Browser Launch + Activation

- **With profile:** `open -na "Google Chrome" --args --profile-directory=<dir> <url>` via `Process`
- **Without profile:** `open -a <AppName> <url>` via `Process`
- **Activation:** `osascript -e 'tell application "<AppName>" to activate'` — reliable foreground focus

## Config File

`~/.hops.toml` — same TOML format as grouter, just renamed:

```toml
[default]
app = "Google Chrome"
profile = "Personal"

[[handlers]]
hostnames = ["localhost"]
hostname_regexps = ['.*\.local$']
app = "Google Chrome"
profile = "Dev"

[[handlers]]
match = ["teams.microsoft.com/l/meetup-join*"]
app = "/Applications/Microsoft Teams.app"

[[handlers]]
match = ["github.com/my-org/*"]
app = "Google Chrome"
profile = "Work"
```

The config model (`HopsConfig`) is shared between the routing engine and the UI. Parse on launch for routing; load into `@Observable` state for the editor.

## Config Window UI

### Layout

```
┌─────────────────────────────────────────────┐
│  hops                                       │
├─────────────────────────────────────────────┤
│  ● hops is your default browser        ✓   │
│  (or: ⚠ Not default  [Set Default Browser])│
├─────────────────────────────────────────────┤
│  Default Browser: [Google Chrome ▾]         │
│  Default Profile: [Personal     ▾]         │
├─────────────────────────────────────────────┤
│  Handlers (first match wins)                │
│  ┌─────────────────────────────────────┐    │
│  │ ≡ localhost, *.local → Chrome/Dev  │ ✎ 🗑│
│  │ ≡ teams.microsoft.* → Teams.app   │ ✎ 🗑│
│  │ ≡ github.com/my-org → Chrome/Work │ ✎ 🗑│
│  └─────────────────────────────────────┘    │
│                              [+ Add Handler]│
├─────────────────────────────────────────────┤
│                    [Save]                   │
└─────────────────────────────────────────────┘
```

### Components

**DefaultBrowserStatus:** Checks if hops is the default handler for `https` via `LSCopyDefaultHandlerForURLScheme`. Shows green checkmark or warning with a button that opens `x-apple.systempreferences:com.apple.Desktop-Settings.extension`.

**Handler List:** SwiftUI `List` with `ForEach` + `.onMove` for drag reordering. Each row shows a summary of patterns and the target app/profile. Edit and delete buttons per row.

**HandlerEditor (sheet):** Presented as a `.sheet` for add/edit:

- Pattern fields: text fields for `match` globs, `hostnames`, `hostname_regexps` (comma-separated or multi-line)
- App picker: button that opens `NSOpenPanel` filtered to `.app` bundles in `/Applications` and `~/Applications`
- Profile picker: dropdown populated from Chrome's `Local State` if the selected app is Google Chrome
- Save/Cancel buttons

**Default Browser section:** App picker + optional profile dropdown for the `[default]` config section.

### Save Behavior

Save button serializes the `HopsConfig` model back to TOML and writes `~/.hops.toml`. Validates before writing (no empty handlers, valid regex patterns).

## Default Browser Prompt

On `applicationDidFinishLaunching`, if in config mode and hops is not the default browser, show an `NSAlert`:

- "hops isn't your default browser. Set it now?"
- [Set Default] → opens System Settings Desktop & Dock pane
- [Later] → dismisses

This alert appears on every config-mode launch where hops is not the default. It's not a one-time nag — it's a helpful nudge since the status is also always visible in the config window header.

Additionally, if `~/.hops.toml` does not exist on launch, create a sensible default config (default browser = Google Chrome, no handlers).

## Build System

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hops",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "hops",
            dependencies: ["TOMLKit"],
            path: "Sources"
        ),
        .testTarget(
            name: "HopsTests",
            dependencies: ["hops"],
            path: "Tests"
        ),
    ]
)
```

### Makefile

```makefile
APP_DIR   = $(HOME)/Applications/hops.app
MACOS_DIR = $(APP_DIR)/Contents/MacOS
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

build:
	swift build -c release
	mkdir -p $(MACOS_DIR)
	cp .build/release/hops $(MACOS_DIR)/

test:
	swift test

install: build
	cp Info.plist $(APP_DIR)/Contents/
	$(LSREGISTER) -f $(APP_DIR)

clean:
	swift package clean
	rm -rf $(APP_DIR)
```

### CI

Same structure as grouter — GitHub Actions with `macos-latest`:

- **ci.yml:** `swift test` on PRs and main pushes
- **release.yml:** On numeric tag push, build universal binary (`--arch arm64 --arch x86_64`), assemble `.app` bundle, zip, publish GitHub Release

## Testing

Port all 27 grouter tests to XCTest:

| Go test file | Swift test file | Coverage |
|---|---|---|
| `cleaner_test.go` | `URLCleanerTests.swift` | UTM/tracking param stripping |
| `matcher_test.go` | `URLMatcherTests.swift` | Glob, hostname, regex matching |
| `config_test.go` | `HopsConfigTests.swift` | TOML parsing, round-trip serialization |
| `profile_test.go` | `ChromeProfileTests.swift` | Chrome Local State → profile dir |
| `router_test.go` | (integrated into matcher/config tests) | Route selection logic |

UI is not unit tested — manual verification for the config window.

## Migration from grouter

Users migrating from grouter:

```bash
cp ~/.grouter.toml ~/.hops.toml
rm -rf ~/Applications/grouter.app
# Set hops as default browser in System Settings
```

The TOML format is identical — only the filename changes.
