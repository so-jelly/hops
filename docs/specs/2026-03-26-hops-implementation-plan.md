# hops Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a pure Swift/SwiftUI macOS URL router with a structured config UI, replacing the Go+Swift grouter architecture.

**Architecture:** Single SwiftUI app with dual-mode behavior — silently routes URLs via Apple Events, shows config window when opened from Finder. SPM with a `HopsCore` library target (routing engine, testable) and `hops` executable target (SwiftUI app + UI).

**Tech Stack:** Swift 5.9+, SwiftUI (macOS 13+), Swift Package Manager, TOMLKit, XCTest

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/HopsCore/HopsCore.swift` (placeholder)
- Create: `Sources/hops/HopsApp.swift` (minimal)
- Create: `Info.plist`
- Create: `Makefile`
- Create: `LICENSE`
- Create: `.gitignore`

- [ ] **Step 1: Create Package.swift**

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
        .target(
            name: "HopsCore",
            dependencies: ["TOMLKit"],
            path: "Sources/HopsCore"
        ),
        .executableTarget(
            name: "hops",
            dependencies: ["HopsCore"],
            path: "Sources/hops"
        ),
        .testTarget(
            name: "HopsTests",
            dependencies: ["HopsCore"],
            path: "Tests"
        ),
    ]
)
```

- [ ] **Step 2: Create minimal HopsCore placeholder**

Create `Sources/HopsCore/HopsCore.swift`:

```swift
import Foundation
```

- [ ] **Step 3: Create minimal HopsApp**

Create `Sources/hops/HopsApp.swift`:

```swift
import SwiftUI

@main
struct HopsApp: App {
    var body: some Scene {
        WindowGroup {
            Text("hops")
        }
    }
}
```

- [ ] **Step 4: Create Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>dev.hops.app</string>
  <key>CFBundleName</key>
  <string>hops</string>
  <key>CFBundleExecutable</key>
  <string>hops</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>Web URL</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>http</string>
        <string>https</string>
      </array>
    </dict>
  </array>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>HTML document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.html</string>
      </array>
    </dict>
    <dict>
      <key>CFBundleTypeName</key>
      <string>XHTML document</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.xhtml</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
```

- [ ] **Step 5: Create Makefile**

```makefile
APP_DIR    = $(HOME)/Applications/hops.app
MACOS_DIR  = $(APP_DIR)/Contents/MacOS
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister

.PHONY: build test install clean

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

- [ ] **Step 6: Create .gitignore**

```
.build/
.swiftpm/
```

- [ ] **Step 7: Create LICENSE**

MIT license, copyright 2026 so-jelly.

- [ ] **Step 8: Resolve dependencies and verify build**

Run: `swift build`
Expected: Fetches TOMLKit, compiles, no errors.

- [ ] **Step 9: Commit**

```bash
git add Package.swift Sources/ Info.plist Makefile LICENSE .gitignore
git commit -m "feat: project scaffolding with SPM, Info.plist, and Makefile"
```

---

### Task 2: URL Cleaner

**Files:**
- Create: `Sources/HopsCore/URLCleaner.swift`
- Create: `Tests/URLCleanerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/URLCleanerTests.swift`:

```swift
import XCTest
@testable import HopsCore

final class URLCleanerTests: XCTestCase {
    func testStripsUtmSource() {
        XCTAssertEqual(
            URLCleaner.clean("https://example.com?utm_source=twitter&real=keep"),
            "https://example.com?real=keep"
        )
    }

    func testStripsMultipleUtmParams() {
        XCTAssertEqual(
            URLCleaner.clean("https://example.com?utm_source=x&utm_medium=y&utm_campaign=z&keep=1"),
            "https://example.com?keep=1"
        )
    }

    func testStripsUtaPrefixedParams() {
        XCTAssertEqual(
            URLCleaner.clean("https://example.com?uta_id=123&real=keep"),
            "https://example.com?real=keep"
        )
    }

    func testStripsFbclidAndGclid() {
        XCTAssertEqual(
            URLCleaner.clean("https://example.com?fbclid=abc&gclid=def&keep=1"),
            "https://example.com?keep=1"
        )
    }

    func testPreservesURLWithNoTrackingParams() {
        XCTAssertEqual(
            URLCleaner.clean("https://example.com?page=1&sort=name"),
            "https://example.com?page=1&sort=name"
        )
    }

    func testHandlesURLWithNoQueryParams() {
        XCTAssertEqual(
            URLCleaner.clean("https://example.com/path"),
            "https://example.com/path"
        )
    }

    func testStripsAllParamsWhenAllAreTracking() {
        XCTAssertEqual(
            URLCleaner.clean("https://example.com?utm_source=x&fbclid=y"),
            "https://example.com"
        )
    }

    func testHandlesMalformedURLGracefully() {
        XCTAssertEqual(
            URLCleaner.clean("not-a-url"),
            "not-a-url"
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter URLCleanerTests`
Expected: Compilation error — `URLCleaner` not defined.

- [ ] **Step 3: Write the implementation**

Create `Sources/HopsCore/URLCleaner.swift`:

```swift
import Foundation

public enum URLCleaner {
    private static let trackingPrefixes = ["utm_", "uta_"]
    private static let trackingExact: Set<String> = ["fbclid", "gclid"]

    public static func clean(_ rawURL: String) -> String {
        guard var components = URLComponents(string: rawURL),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return rawURL
        }

        let filtered = queryItems.filter { item in
            if trackingExact.contains(item.name) { return false }
            for prefix in trackingPrefixes {
                if item.name.hasPrefix(prefix) { return false }
            }
            return true
        }

        if filtered.count == queryItems.count {
            return rawURL
        }

        components.queryItems = filtered.isEmpty ? nil : filtered
        return components.string ?? rawURL
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter URLCleanerTests`
Expected: All 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HopsCore/URLCleaner.swift Tests/URLCleanerTests.swift
git commit -m "feat: add URL cleaner with tracking param stripping"
```

---

### Task 3: URL Matcher

**Files:**
- Create: `Sources/HopsCore/URLMatcher.swift`
- Create: `Tests/URLMatcherTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/URLMatcherTests.swift`:

```swift
import XCTest
@testable import HopsCore

final class GlobMatcherTests: XCTestCase {
    func testExactDomainWithWildcardPath() {
        let m = GlobMatcher(pattern: "github.com/wartsilaeso/*")
        XCTAssertTrue(m.matches(URL(string: "https://github.com/wartsilaeso/sitebuilder")!))
    }

    func testWildcardSubdomain() {
        let m = GlobMatcher(pattern: "*.atlassian.net/*")
        XCTAssertTrue(m.matches(URL(string: "https://greensmith.atlassian.net/browse/CAT-123")!))
    }

    func testNoMatchOnDifferentDomain() {
        let m = GlobMatcher(pattern: "*.atlassian.net/*")
        XCTAssertFalse(m.matches(URL(string: "https://example.com/foo")!))
    }

    func testPathPrefixWithWildcard() {
        let m = GlobMatcher(pattern: "teams.microsoft.com/l/meetup-join*")
        XCTAssertTrue(m.matches(URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc")!))
    }

    func testNoMatchOnWrongPath() {
        let m = GlobMatcher(pattern: "teams.microsoft.com/l/meetup-join*")
        XCTAssertFalse(m.matches(URL(string: "https://teams.microsoft.com/other/path")!))
    }

    func testExactDomainNoPath() {
        let m = GlobMatcher(pattern: "bitbucket.org/*")
        XCTAssertTrue(m.matches(URL(string: "https://bitbucket.org/wartsilaeso/repo")!))
    }

    func testPersonalNotMatchedByOrgPattern() {
        let m = GlobMatcher(pattern: "github.com/wartsilaeso/*")
        XCTAssertFalse(m.matches(URL(string: "https://github.com/other-user/repo")!))
    }
}

final class HostnameMatcherTests: XCTestCase {
    func testExactHostnameMatch() {
        let m = HostnameMatcher(hostnames: ["localhost"], regexPatterns: [])
        XCTAssertTrue(m.matches(URL(string: "http://localhost:3000/foo")!))
    }

    func testNoMatchOnDifferentHostname() {
        let m = HostnameMatcher(hostnames: ["localhost"], regexPatterns: [])
        XCTAssertFalse(m.matches(URL(string: "https://example.com/foo")!))
    }

    func testRegexHostnameMatch() {
        let m = HostnameMatcher(hostnames: [], regexPatterns: [#".*\.local$"#])
        XCTAssertTrue(m.matches(URL(string: "http://myapp.local:8080/api")!))
    }

    func testRegexNoMatch() {
        let m = HostnameMatcher(hostnames: [], regexPatterns: [#".*\.local$"#])
        XCTAssertFalse(m.matches(URL(string: "https://example.com")!))
    }

    func testMixedStringOrRegex() {
        let m = HostnameMatcher(hostnames: ["localhost"], regexPatterns: [#".*\.local$"#])
        XCTAssertTrue(m.matches(URL(string: "http://dev.local/test")!))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter "GlobMatcherTests|HostnameMatcherTests"`
Expected: Compilation error — types not defined.

- [ ] **Step 3: Write the implementation**

Create `Sources/HopsCore/URLMatcher.swift`:

```swift
import Foundation

public protocol URLMatchable {
    func matches(_ url: URL) -> Bool
}

public struct GlobMatcher: URLMatchable {
    public let pattern: String
    private let regex: NSRegularExpression?

    public init(pattern: String) {
        self.pattern = pattern
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        let regexPattern = "^" + escaped.replacingOccurrences(of: "\\*", with: ".*") + "$"
        self.regex = try? NSRegularExpression(pattern: regexPattern)
    }

    public func matches(_ url: URL) -> Bool {
        guard let regex else { return false }
        let hostname = url.host ?? ""
        let path = url.path
        // Strip port for matching (patterns don't include ports)
        let target = hostname + path
        let range = NSRange(target.startIndex..., in: target)
        return regex.firstMatch(in: target, range: range) != nil
    }
}

public struct HostnameMatcher: URLMatchable {
    public let hostnames: [String]
    public let regexPatterns: [String]
    private let compiledRegexes: [NSRegularExpression]

    public init(hostnames: [String], regexPatterns: [String]) {
        self.hostnames = hostnames
        self.regexPatterns = regexPatterns
        self.compiledRegexes = regexPatterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }

    public func matches(_ url: URL) -> Bool {
        let hostname = url.host ?? ""
        for hn in hostnames {
            if hostname == hn { return true }
        }
        for re in compiledRegexes {
            let range = NSRange(hostname.startIndex..., in: hostname)
            if re.firstMatch(in: hostname, range: range) != nil { return true }
        }
        return false
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter "GlobMatcherTests|HostnameMatcherTests"`
Expected: All 12 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HopsCore/URLMatcher.swift Tests/URLMatcherTests.swift
git commit -m "feat: add glob and hostname URL matchers"
```

---

### Task 4: Chrome Profile Resolver

**Files:**
- Create: `Sources/HopsCore/ChromeProfile.swift`
- Create: `Tests/ChromeProfileTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/ChromeProfileTests.swift`:

```swift
import XCTest
@testable import HopsCore

final class ChromeProfileTests: XCTestCase {
    let testLocalState = """
    {
        "profile": {
            "info_cache": {
                "Default": {"name": "Person 1"},
                "Profile 2": {"name": "wart"},
                "Profile 4": {"name": "Dev"}
            }
        }
    }
    """

    func writeTestLocalState() -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("Local State")
        try! testLocalState.write(to: path, atomically: true, encoding: .utf8)
        return path.path
    }

    func testResolvePerson1() throws {
        let path = writeTestLocalState()
        let dir = try ChromeProfile.resolveProfileDir(localStatePath: path, displayName: "Person 1")
        XCTAssertEqual(dir, "Default")
    }

    func testResolveWart() throws {
        let path = writeTestLocalState()
        let dir = try ChromeProfile.resolveProfileDir(localStatePath: path, displayName: "wart")
        XCTAssertEqual(dir, "Profile 2")
    }

    func testResolveDev() throws {
        let path = writeTestLocalState()
        let dir = try ChromeProfile.resolveProfileDir(localStatePath: path, displayName: "Dev")
        XCTAssertEqual(dir, "Profile 4")
    }

    func testResolveNonExistentThrows() {
        let path = writeTestLocalState()
        XCTAssertThrowsError(
            try ChromeProfile.resolveProfileDir(localStatePath: path, displayName: "NonExistent")
        )
    }

    func testListProfiles() throws {
        let path = writeTestLocalState()
        let profiles = try ChromeProfile.listProfiles(localStatePath: path)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertTrue(profiles.contains { $0.displayName == "wart" && $0.directory == "Profile 2" })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ChromeProfileTests`
Expected: Compilation error — `ChromeProfile` not defined.

- [ ] **Step 3: Write the implementation**

Create `Sources/HopsCore/ChromeProfile.swift`:

```swift
import Foundation

public enum ChromeProfile {
    public struct ProfileInfo {
        public let directory: String
        public let displayName: String
    }

    enum ProfileError: LocalizedError {
        case readFailed(String)
        case parseFailed(String)
        case profileNotFound(String)

        var errorDescription: String? {
            switch self {
            case .readFailed(let msg): return "Reading Local State: \(msg)"
            case .parseFailed(let msg): return "Parsing Local State: \(msg)"
            case .profileNotFound(let name): return "Chrome profile \"\(name)\" not found"
            }
        }
    }

    public static func resolveProfileDir(localStatePath: String, displayName: String) throws -> String {
        let profiles = try loadInfoCache(localStatePath: localStatePath)
        guard let entry = profiles.first(where: { $0.value == displayName }) else {
            throw ProfileError.profileNotFound(displayName)
        }
        return entry.key
    }

    public static func listProfiles(localStatePath: String? = nil) throws -> [ProfileInfo] {
        let path = localStatePath ?? defaultLocalStatePath()
        let cache = try loadInfoCache(localStatePath: path)
        return cache.map { ProfileInfo(directory: $0.key, displayName: $0.value) }
    }

    public static func defaultLocalStatePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/Google/Chrome/Local State"
    }

    private static func loadInfoCache(localStatePath: String) throws -> [String: String] {
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: localStatePath))
        } catch {
            throw ProfileError.readFailed(error.localizedDescription)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = json["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: [String: Any]] else {
            throw ProfileError.parseFailed("unexpected JSON structure")
        }

        var result: [String: String] = [:]
        for (dir, info) in infoCache {
            if let name = info["name"] as? String {
                result[dir] = name
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ChromeProfileTests`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/HopsCore/ChromeProfile.swift Tests/ChromeProfileTests.swift
git commit -m "feat: add Chrome profile resolver"
```

---

### Task 5: Config Parser + Serializer

**Files:**
- Create: `Sources/HopsCore/HopsConfig.swift`
- Create: `Tests/HopsConfigTests.swift`
- Remove: `Sources/HopsCore/HopsCore.swift` (placeholder)

- [ ] **Step 1: Write the failing tests**

Create `Tests/HopsConfigTests.swift`:

```swift
import XCTest
@testable import HopsCore

final class HopsConfigTests: XCTestCase {
    let testConfig = """
    [default]
    app = "Google Chrome"
    profile = "Person 1"

    [[handlers]]
    hostnames = ["localhost"]
    hostname_regexps = ['.*\\.local$']
    app = "Google Chrome"
    profile = "Dev"

    [[handlers]]
    match = ["teams.microsoft.com/l/meetup-join*"]
    app = "/Applications/Microsoft Teams.app"

    [[handlers]]
    match = ["github.com/wartsilaeso/*"]
    app = "Google Chrome"
    profile = "wart"

    [[handlers]]
    match = ["*.atlassian.net/*", "console.cloud.google.com/*"]
    app = "Google Chrome"
    profile = "wart"
    """

    func testParseDefaultBrowser() throws {
        let config = try HopsConfig.parse(testConfig)
        XCTAssertEqual(config.defaultBrowser.app, "Google Chrome")
        XCTAssertEqual(config.defaultBrowser.profile, "Person 1")
    }

    func testParseHandlerCount() throws {
        let config = try HopsConfig.parse(testConfig)
        XCTAssertEqual(config.handlers.count, 4)
    }

    func testParseHostnameHandler() throws {
        let config = try HopsConfig.parse(testConfig)
        let h0 = config.handlers[0]
        XCTAssertEqual(h0.hostnames, ["localhost"])
        XCTAssertEqual(h0.hostnameRegexps, [#".*\.local$"#])
        XCTAssertEqual(h0.app, "Google Chrome")
        XCTAssertEqual(h0.profile, "Dev")
    }

    func testParseAppPathHandler() throws {
        let config = try HopsConfig.parse(testConfig)
        let h1 = config.handlers[1]
        XCTAssertEqual(h1.match, ["teams.microsoft.com/l/meetup-join*"])
        XCTAssertEqual(h1.app, "/Applications/Microsoft Teams.app")
        XCTAssertEqual(h1.profile, "")
    }

    func testParseMultiGlobHandler() throws {
        let config = try HopsConfig.parse(testConfig)
        let h3 = config.handlers[3]
        XCTAssertEqual(h3.match, ["*.atlassian.net/*", "console.cloud.google.com/*"])
        XCTAssertEqual(h3.profile, "wart")
    }

    func testParseConfigFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let path = tmpDir.appendingPathComponent("test.hops.toml").path
        try testConfig.write(toFile: path, atomically: true, encoding: .utf8)

        let config = try HopsConfig.parseFile(path)
        XCTAssertEqual(config.handlers.count, 4)
    }

    func testSerializeRoundTrip() throws {
        let config = try HopsConfig.parse(testConfig)
        let serialized = config.serialize()
        let reparsed = try HopsConfig.parse(serialized)
        XCTAssertEqual(reparsed.defaultBrowser.app, config.defaultBrowser.app)
        XCTAssertEqual(reparsed.defaultBrowser.profile, config.defaultBrowser.profile)
        XCTAssertEqual(reparsed.handlers.count, config.handlers.count)
    }

    func testRouteLocalhostToDevProfile() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "http://localhost:3000/foo")!)
        XCTAssertEqual(target.app, "Google Chrome")
        XCTAssertEqual(target.profile, "Dev")
    }

    func testRouteDotLocalToDevProfile() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "http://myapp.local:8080/api")!)
        XCTAssertEqual(target.profile, "Dev")
    }

    func testRouteTeamsToNativeApp() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "https://teams.microsoft.com/l/meetup-join/abc")!)
        XCTAssertEqual(target.app, "/Applications/Microsoft Teams.app")
        XCTAssertEqual(target.profile, "")
    }

    func testRouteGitHubWorkOrg() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "https://github.com/wartsilaeso/sitebuilder")!)
        XCTAssertEqual(target.profile, "wart")
    }

    func testRouteGitHubPersonalFallback() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "https://github.com/other/repo")!)
        XCTAssertEqual(target.profile, "Person 1")
    }

    func testRouteAtlassianWork() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "https://greensmith.atlassian.net/browse/CAT-1")!)
        XCTAssertEqual(target.profile, "wart")
    }

    func testRouteGcloudWork() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "https://console.cloud.google.com/home")!)
        XCTAssertEqual(target.profile, "wart")
    }

    func testRouteUnknownDomainDefault() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "https://example.com/page")!)
        XCTAssertEqual(target.profile, "Person 1")
        XCTAssertEqual(target.app, "Google Chrome")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter HopsConfigTests`
Expected: Compilation error — `HopsConfig` not defined.

- [ ] **Step 3: Write the implementation**

Create `Sources/HopsCore/HopsConfig.swift`:

```swift
import Foundation
import TOMLKit

public struct BrowserTarget: Equatable {
    public var app: String
    public var profile: String

    public init(app: String = "Google Chrome", profile: String = "") {
        self.app = app
        self.profile = profile
    }
}

public struct HandlerConfig: Identifiable, Equatable {
    public let id: UUID
    public var match: [String]
    public var hostnames: [String]
    public var hostnameRegexps: [String]
    public var app: String
    public var profile: String

    public init(
        id: UUID = UUID(),
        match: [String] = [],
        hostnames: [String] = [],
        hostnameRegexps: [String] = [],
        app: String = "Google Chrome",
        profile: String = ""
    ) {
        self.id = id
        self.match = match
        self.hostnames = hostnames
        self.hostnameRegexps = hostnameRegexps
        self.app = app
        self.profile = profile
    }

    func buildMatchers() -> [any URLMatchable] {
        var matchers: [any URLMatchable] = []
        if !hostnames.isEmpty || !hostnameRegexps.isEmpty {
            matchers.append(HostnameMatcher(hostnames: hostnames, regexPatterns: hostnameRegexps))
        }
        for pattern in match {
            matchers.append(GlobMatcher(pattern: pattern))
        }
        return matchers
    }

    var summary: String {
        let patterns = match + hostnames + hostnameRegexps
        let patternText = patterns.joined(separator: ", ")
        let targetText = profile.isEmpty ? app : "\(app)/\(profile)"
        return "\(patternText) → \(targetText)"
    }
}

public struct HopsConfig {
    public var defaultBrowser: BrowserTarget
    public var handlers: [HandlerConfig]

    public init(defaultBrowser: BrowserTarget = BrowserTarget(), handlers: [HandlerConfig] = []) {
        self.defaultBrowser = defaultBrowser
        self.handlers = handlers
    }

    public static func parse(_ source: String) throws -> HopsConfig {
        let table = try TOMLTable(string: source)

        var config = HopsConfig()

        if let defaultTable = table["default"] as? TOMLTable {
            config.defaultBrowser.app = (defaultTable["app"] as? String) ?? "Google Chrome"
            config.defaultBrowser.profile = (defaultTable["profile"] as? String) ?? ""
        }

        if let handlersArray = table["handlers"] as? TOMLArray {
            for i in 0..<handlersArray.count {
                guard let handlerTable = handlersArray[i] as? TOMLTable else { continue }

                var handler = HandlerConfig()

                handler.app = (handlerTable["app"] as? String) ?? "Google Chrome"
                handler.profile = (handlerTable["profile"] as? String) ?? ""

                if let matchArray = handlerTable["match"] as? TOMLArray {
                    handler.match = (0..<matchArray.count).compactMap { matchArray[$0] as? String }
                }
                if let hostnamesArray = handlerTable["hostnames"] as? TOMLArray {
                    handler.hostnames = (0..<hostnamesArray.count).compactMap { hostnamesArray[$0] as? String }
                }
                if let regexArray = handlerTable["hostname_regexps"] as? TOMLArray {
                    handler.hostnameRegexps = (0..<regexArray.count).compactMap { regexArray[$0] as? String }
                }

                config.handlers.append(handler)
            }
        }

        return config
    }

    public static func parseFile(_ path: String) throws -> HopsConfig {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(source)
    }

    public func serialize() -> String {
        var lines: [String] = []

        lines.append("[default]")
        lines.append("app = \"\(defaultBrowser.app)\"")
        if !defaultBrowser.profile.isEmpty {
            lines.append("profile = \"\(defaultBrowser.profile)\"")
        }

        for handler in handlers {
            lines.append("")
            lines.append("[[handlers]]")

            if !handler.hostnames.isEmpty {
                let quoted = handler.hostnames.map { "\"\($0)\"" }
                lines.append("hostnames = [\(quoted.joined(separator: ", "))]")
            }
            if !handler.hostnameRegexps.isEmpty {
                let quoted = handler.hostnameRegexps.map { "'\($0)'" }
                lines.append("hostname_regexps = [\(quoted.joined(separator: ", "))]")
            }
            if !handler.match.isEmpty {
                let quoted = handler.match.map { "\"\($0)\"" }
                lines.append("match = [\(quoted.joined(separator: ", "))]")
            }

            lines.append("app = \"\(handler.app)\"")
            if !handler.profile.isEmpty {
                lines.append("profile = \"\(handler.profile)\"")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    public static func configFilePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.hops.toml"
    }

    public func route(_ url: URL) -> BrowserTarget {
        for handler in handlers {
            let matchers = handler.buildMatchers()
            for matcher in matchers {
                if matcher.matches(url) {
                    return BrowserTarget(app: handler.app, profile: handler.profile)
                }
            }
        }
        return defaultBrowser
    }
}
```

- [ ] **Step 4: Delete the placeholder file**

```bash
rm Sources/HopsCore/HopsCore.swift
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter HopsConfigTests`
Expected: All 15 tests PASS.

- [ ] **Step 6: Run all tests**

Run: `swift test`
Expected: All 25 tests PASS (8 cleaner + 12 matcher + 5 profile).

Note: The config tests include routing tests (the 8 `testRoute*` methods), so the total replaces grouter's separate `router_test.go`.

- [ ] **Step 7: Commit**

```bash
git add Sources/HopsCore/HopsConfig.swift Tests/HopsConfigTests.swift
git rm Sources/HopsCore/HopsCore.swift
git commit -m "feat: add TOML config parser, serializer, and URL router"
```

---

### Task 6: Browser Launcher

**Files:**
- Create: `Sources/HopsCore/Launcher.swift`

- [ ] **Step 1: Write the implementation**

Create `Sources/HopsCore/Launcher.swift`:

```swift
import Foundation

public enum Launcher {
    public static func launch(target: BrowserTarget, cleanedURL: String) {
        if !target.profile.isEmpty {
            if let profileDir = try? ChromeProfile.resolveProfileDir(
                localStatePath: ChromeProfile.defaultLocalStatePath(),
                displayName: target.profile
            ) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-na", target.app, "--args",
                                     "--profile-directory=\(profileDir)", cleanedURL]
                try? process.run()
                process.waitUntilExit()
            } else {
                // Fallback: open without profile
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = ["-a", target.app, cleanedURL]
                try? process.run()
                process.waitUntilExit()
            }
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", target.app, cleanedURL]
            try? process.run()
            process.waitUntilExit()
        }

        // Activate the target app so it comes to the foreground
        let activate = Process()
        activate.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        activate.arguments = ["-e", "tell application \"\(target.app)\" to activate"]
        try? activate.run()
        activate.waitUntilExit()
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Compiles with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/HopsCore/Launcher.swift
git commit -m "feat: add browser launcher with profile resolution and focus activation"
```

---

### Task 7: Dual-Mode App (Apple Events + Config Window)

**Files:**
- Modify: `Sources/hops/HopsApp.swift`
- Create: `Sources/hops/AppDelegate.swift`

- [ ] **Step 1: Create the AppDelegate for Apple Event handling**

Create `Sources/hops/AppDelegate.swift`:

```swift
import Cocoa
import HopsCore

class AppDelegate: NSObject, NSApplicationDelegate {
    var receivedURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc func handleGetURL(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }
        receivedURL = true
        routeURL(urlString)
    }

    private func routeURL(_ rawURL: String) {
        guard let url = URL(string: rawURL) else {
            // Fallback: open with system default
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [rawURL]
            try? process.run()
            NSApp.terminate(nil)
            return
        }

        let configPath = HopsConfig.configFilePath()
        guard let config = try? HopsConfig.parseFile(configPath) else {
            // No config or parse error — open with system default
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [rawURL]
            try? process.run()
            NSApp.terminate(nil)
            return
        }

        let target = config.route(url)
        let cleanedURL = URLCleaner.clean(rawURL)
        Launcher.launch(target: target, cleanedURL: cleanedURL)
        NSApp.terminate(nil)
    }
}
```

- [ ] **Step 2: Update HopsApp to use the delegate and show config window conditionally**

Replace `Sources/hops/HopsApp.swift`:

```swift
import SwiftUI
import HopsCore

@main
struct HopsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ConfigWindow()
        }
        .handlesExternalEvents(matching: [])
    }
}
```

Note: The `WindowGroup` shows the config window when launched directly. When launched via Apple Event, the `AppDelegate` handles the URL and calls `NSApp.terminate(nil)` before the window appears. `.handlesExternalEvents(matching: [])` prevents the window from opening on URL events.

- [ ] **Step 3: Create a stub ConfigWindow**

Create `Sources/hops/UI/ConfigWindow.swift`:

```swift
import SwiftUI
import HopsCore

struct ConfigWindow: View {
    var body: some View {
        VStack {
            Text("hops")
                .font(.title)
            Text("Config UI coming next...")
        }
        .frame(width: 500, height: 400)
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `swift build`
Expected: Compiles with no errors.

- [ ] **Step 5: Commit**

```bash
git add Sources/hops/
git commit -m "feat: dual-mode app — Apple Event URL routing + config window shell"
```

---

### Task 8: Default Browser Status View

**Files:**
- Create: `Sources/hops/UI/DefaultBrowserStatus.swift`

- [ ] **Step 1: Write the implementation**

Create `Sources/hops/UI/DefaultBrowserStatus.swift`:

```swift
import SwiftUI
import CoreServices

struct DefaultBrowserStatus: View {
    @State private var isDefault = false

    var body: some View {
        HStack {
            if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("hops is your default browser")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("hops is not your default browser")
                Spacer()
                Button("Set Default Browser") {
                    openDesktopDockSettings()
                }
            }
            Spacer()
        }
        .padding()
        .background(.quaternary)
        .cornerRadius(8)
        .onAppear { checkDefault() }
    }

    private func checkDefault() {
        if let handler = LSCopyDefaultHandlerForURLScheme("https" as CFString)?.takeRetainedValue() {
            isDefault = (handler as String) == "dev.hops.app"
        }
    }

    private func openDesktopDockSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `swift build`
Expected: Compiles with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/hops/UI/DefaultBrowserStatus.swift
git commit -m "feat: add default browser status view with settings launcher"
```

---

### Task 9: Handler Editor Sheet

**Files:**
- Create: `Sources/hops/UI/HandlerEditor.swift`

- [ ] **Step 1: Write the implementation**

Create `Sources/hops/UI/HandlerEditor.swift`:

```swift
import SwiftUI
import HopsCore

struct HandlerEditor: View {
    @Binding var handler: HandlerConfig
    @Environment(\.dismiss) private var dismiss

    @State private var matchText: String = ""
    @State private var hostnamesText: String = ""
    @State private var regexpsText: String = ""
    @State private var app: String = ""
    @State private var profile: String = ""
    @State private var chromeProfiles: [ChromeProfile.ProfileInfo] = []

    var isChrome: Bool {
        app.localizedCaseInsensitiveContains("Google Chrome")
    }

    var body: some View {
        Form {
            Section("URL Patterns") {
                TextField("Glob patterns (comma-separated)", text: $matchText, axis: .vertical)
                    .lineLimit(3)
                TextField("Hostnames (comma-separated)", text: $hostnamesText)
                TextField("Hostname regexps (comma-separated)", text: $regexpsText)
            }

            Section("Target Application") {
                HStack {
                    TextField("App", text: $app)
                    Button("Browse...") { browseForApp() }
                }
                if isChrome {
                    Picker("Profile", selection: $profile) {
                        Text("None").tag("")
                        ForEach(chromeProfiles, id: \.directory) { p in
                            Text(p.displayName).tag(p.displayName)
                        }
                    }
                }
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(app.isEmpty)
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 450)
        .onAppear { loadFromHandler() }
    }

    private func loadFromHandler() {
        matchText = handler.match.joined(separator: ", ")
        hostnamesText = handler.hostnames.joined(separator: ", ")
        regexpsText = handler.hostnameRegexps.joined(separator: ", ")
        app = handler.app
        profile = handler.profile
        chromeProfiles = (try? ChromeProfile.listProfiles()) ?? []
    }

    private func save() {
        handler.match = splitComma(matchText)
        handler.hostnames = splitComma(hostnamesText)
        handler.hostnameRegexps = splitComma(regexpsText)
        handler.app = app
        handler.profile = isChrome ? profile : ""
        dismiss()
    }

    private func splitComma(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            app = url.path
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `swift build`
Expected: Compiles with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/hops/UI/HandlerEditor.swift
git commit -m "feat: add handler editor sheet with app browser and profile picker"
```

---

### Task 10: Config Window (Full Implementation)

**Files:**
- Modify: `Sources/hops/UI/ConfigWindow.swift`

- [ ] **Step 1: Replace the stub with the full config window**

Replace `Sources/hops/UI/ConfigWindow.swift`:

```swift
import SwiftUI
import HopsCore

struct ConfigWindow: View {
    @State private var config = HopsConfig()
    @State private var editingHandler: HandlerConfig?
    @State private var isAddingHandler = false
    @State private var showSaveConfirmation = false
    @State private var chromeProfiles: [ChromeProfile.ProfileInfo] = []

    var isChrome: Bool {
        config.defaultBrowser.app.localizedCaseInsensitiveContains("Google Chrome")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("hops")
                .font(.largeTitle.bold())

            DefaultBrowserStatus()

            GroupBox("Default Browser") {
                VStack(alignment: .leading) {
                    HStack {
                        TextField("App", text: $config.defaultBrowser.app)
                        Button("Browse...") { browseDefaultApp() }
                    }
                    if isChrome {
                        Picker("Profile", selection: $config.defaultBrowser.profile) {
                            Text("None").tag("")
                            ForEach(chromeProfiles, id: \.directory) { p in
                                Text(p.displayName).tag(p.displayName)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            GroupBox {
                VStack(alignment: .leading) {
                    Text("Handlers")
                        .font(.headline)
                    Text("First match wins. Drag to reorder.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    List {
                        ForEach($config.handlers) { $handler in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(handler.summary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button {
                                    editingHandler = handler
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    config.handlers.removeAll { $0.id == handler.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                        }
                        .onMove { indices, newOffset in
                            config.handlers.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .frame(minHeight: 120)

                    HStack {
                        Spacer()
                        Button("Add Handler") {
                            isAddingHandler = true
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button("Save") { saveConfig() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 550, minHeight: 500)
        .onAppear { loadConfig() }
        .sheet(item: $editingHandler) { handler in
            let binding = Binding<HandlerConfig>(
                get: { config.handlers.first { $0.id == handler.id } ?? handler },
                set: { updated in
                    if let idx = config.handlers.firstIndex(where: { $0.id == handler.id }) {
                        config.handlers[idx] = updated
                    }
                }
            )
            HandlerEditor(handler: binding)
        }
        .sheet(isPresented: $isAddingHandler) {
            let newHandler = HandlerConfig()
            let binding = Binding<HandlerConfig>(
                get: { newHandler },
                set: { created in
                    config.handlers.append(created)
                }
            )
            HandlerEditor(handler: binding)
        }
        .alert("Saved", isPresented: $showSaveConfirmation) {
            Button("OK") {}
        } message: {
            Text("Configuration saved to ~/.hops.toml")
        }
    }

    private func loadConfig() {
        let path = HopsConfig.configFilePath()
        if FileManager.default.fileExists(atPath: path) {
            config = (try? HopsConfig.parseFile(path)) ?? HopsConfig()
        }
        chromeProfiles = (try? ChromeProfile.listProfiles()) ?? []
    }

    private func saveConfig() {
        let path = HopsConfig.configFilePath()
        let content = config.serialize()
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
        showSaveConfirmation = true
    }

    private func browseDefaultApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Default Application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            config.defaultBrowser.app = url.path
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `swift build`
Expected: Compiles with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/hops/UI/ConfigWindow.swift
git commit -m "feat: full config window with handler list, reorder, edit, and save"
```

---

### Task 11: Default Browser Prompt on Launch

**Files:**
- Modify: `Sources/hops/AppDelegate.swift`

- [ ] **Step 1: Add the prompt logic to AppDelegate**

Add to `AppDelegate.swift`, after the existing methods:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    if receivedURL { return }

    // Create default config if none exists
    let configPath = HopsConfig.configFilePath()
    if !FileManager.default.fileExists(atPath: configPath) {
        let defaultConfig = HopsConfig()
        let content = defaultConfig.serialize()
        try? content.write(toFile: configPath, atomically: true, encoding: .utf8)
    }

    // Prompt if not default browser
    if let handler = LSCopyDefaultHandlerForURLScheme("https" as CFString)?.takeRetainedValue() {
        if (handler as String) != "dev.hops.app" {
            showDefaultBrowserPrompt()
        }
    }
}

private func showDefaultBrowserPrompt() {
    let alert = NSAlert()
    alert.messageText = "hops isn't your default browser"
    alert.informativeText = "Set hops as your default browser to route URLs automatically."
    alert.addButton(withTitle: "Set Default")
    alert.addButton(withTitle: "Later")
    alert.alertStyle = .informational

    if alert.runModal() == .alertFirstButtonReturn {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Add CoreServices import to AppDelegate**

Add `import CoreServices` at the top of `AppDelegate.swift`.

- [ ] **Step 3: Build and verify**

Run: `swift build`
Expected: Compiles with no errors.

- [ ] **Step 4: Commit**

```bash
git add Sources/hops/AppDelegate.swift
git commit -m "feat: prompt to set default browser on config-mode launch"
```

---

### Task 12: CI Workflows

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift test

  build:
    runs-on: macos-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - name: Build universal binary
        run: swift build -c release --arch arm64 --arch x86_64
      - name: Verify binary
        run: |
          file .build/apple/Products/Release/hops
          lipo -info .build/apple/Products/Release/hops
```

- [ ] **Step 2: Create release workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags: ["[0-9]*"]

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - run: swift test

      - name: Build universal binary
        run: swift build -c release --arch arm64 --arch x86_64

      - name: Assemble app bundle and zip
        env:
          TAG_NAME: ${{ github.ref_name }}
        run: |
          mkdir -p hops.app/Contents/MacOS
          cp .build/apple/Products/Release/hops hops.app/Contents/MacOS/
          cp Info.plist hops.app/Contents/
          zip -r "hops-${TAG_NAME}.zip" hops.app

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          files: hops-*.zip
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/release.yml
git commit -m "ci: add CI and release workflows"
```

---

### Task 13: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

Create `README.md` with:

- Project description (macOS URL router)
- How it works (dual-mode: URL routing via Apple Events, config window via Finder)
- Install from source (`make install`)
- Configuration section with example `~/.hops.toml`
- Matching rules reference
- URL cleaning description
- App bundle layout (single binary now)
- Development commands (`make test`, `make build`, etc.)
- Migration from grouter section
- License

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

### Task 14: Build, Install, and Verify

- [ ] **Step 1: Run full test suite**

Run: `swift test`
Expected: All tests pass (8 cleaner + 12 matcher + 5 profile + 15 config = 40 tests).

- [ ] **Step 2: Build and install**

Run: `make install`
Expected: Builds release binary, copies to `~/Applications/hops.app/Contents/MacOS/`, copies Info.plist, registers with Launch Services.

- [ ] **Step 3: Verify app bundle layout**

```bash
find ~/Applications/hops.app -type f | sort
file ~/Applications/hops.app/Contents/MacOS/hops
```

Expected:
```
~/Applications/hops.app/Contents/Info.plist
~/Applications/hops.app/Contents/MacOS/hops
```
Single binary, Mach-O arm64 (or universal).

- [ ] **Step 4: Copy config from grouter**

```bash
cp ~/.grouter.toml ~/.hops.toml
```

- [ ] **Step 5: Test URL routing**

```bash
~/Applications/hops.app/Contents/MacOS/hops "https://github.com/so-jelly/hops"
```

Expected: Opens in default Chrome profile, Chrome comes to foreground.

- [ ] **Step 6: Test config window**

Open hops.app from Finder. Expected: Config window appears with loaded handlers, default browser status visible.

- [ ] **Step 7: Push and tag**

```bash
git push -u origin main
git tag 1
git push origin 1
```

- [ ] **Step 8: Commit**

No commit needed — this is verification only.
