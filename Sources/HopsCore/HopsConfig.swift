import Foundation
import TOMLKit

// MARK: - BrowserTarget

public struct BrowserTarget: Equatable {
    public var app: String
    public var profile: String

    public init(app: String, profile: String = "") {
        self.app = app
        self.profile = profile
    }
}

// MARK: - HandlerConfig

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
        app: String = "",
        profile: String = ""
    ) {
        self.id = id
        self.match = match
        self.hostnames = hostnames
        self.hostnameRegexps = hostnameRegexps
        self.app = app
        self.profile = profile
    }

    /// A human-readable description of what this handler matches.
    public var summary: String {
        var parts: [String] = []
        if !hostnames.isEmpty {
            parts.append("hosts: \(hostnames.joined(separator: ", "))")
        }
        if !hostnameRegexps.isEmpty {
            parts.append("regexps: \(hostnameRegexps.joined(separator: ", "))")
        }
        if !match.isEmpty {
            parts.append("globs: \(match.joined(separator: ", "))")
        }
        return parts.isEmpty ? "(empty)" : parts.joined(separator: "; ")
    }

    /// Builds the set of URL matchers for this handler.
    public func buildMatchers() -> [any URLMatchable] {
        var matchers: [any URLMatchable] = []
        if !hostnames.isEmpty || !hostnameRegexps.isEmpty {
            matchers.append(HostnameMatcher(hostnames: hostnames, regexPatterns: hostnameRegexps))
        }
        for pattern in match {
            matchers.append(GlobMatcher(pattern: pattern))
        }
        return matchers
    }

    /// Whether any matcher in this handler matches the given URL.
    func matchesURL(_ url: URL) -> Bool {
        buildMatchers().contains { $0.matches(url) }
    }
}

// MARK: - HopsConfig

public struct HopsConfig {
    public var defaultBrowser: BrowserTarget
    public var handlers: [HandlerConfig]

    public init(defaultBrowser: BrowserTarget = BrowserTarget(app: "", profile: ""), handlers: [HandlerConfig] = []) {
        self.defaultBrowser = defaultBrowser
        self.handlers = handlers
    }

    // MARK: Parsing

    /// Parse a TOML string into a HopsConfig.
    public static func parse(_ source: String) throws -> HopsConfig {
        let table = try TOMLTable(string: source)

        // Parse [default]
        let defaultBrowser: BrowserTarget
        if let defaultTable = table["default"]?.table {
            let app = defaultTable["app"]?.string ?? ""
            let profile = defaultTable["profile"]?.string ?? ""
            defaultBrowser = BrowserTarget(app: app, profile: profile)
        } else {
            defaultBrowser = BrowserTarget(app: "", profile: "")
        }

        // Parse [[handlers]]
        var handlers: [HandlerConfig] = []
        if let handlersArray = table["handlers"]?.array {
            for element in handlersArray {
                guard let handlerTable = element.table else { continue }

                let app = handlerTable["app"]?.string ?? ""
                let profile = handlerTable["profile"]?.string ?? ""

                let match: [String]
                if let matchArray = handlerTable["match"]?.array {
                    match = matchArray.compactMap { $0.string }
                } else {
                    match = []
                }

                let hostnames: [String]
                if let hostnamesArray = handlerTable["hostnames"]?.array {
                    hostnames = hostnamesArray.compactMap { $0.string }
                } else {
                    hostnames = []
                }

                let hostnameRegexps: [String]
                if let regexpsArray = handlerTable["hostname_regexps"]?.array {
                    hostnameRegexps = regexpsArray.compactMap { $0.string }
                } else {
                    hostnameRegexps = []
                }

                handlers.append(HandlerConfig(
                    match: match,
                    hostnames: hostnames,
                    hostnameRegexps: hostnameRegexps,
                    app: app,
                    profile: profile
                ))
            }
        }

        return HopsConfig(defaultBrowser: defaultBrowser, handlers: handlers)
    }

    /// Parse a TOML file at the given path into a HopsConfig.
    public static func parseFile(_ path: String) throws -> HopsConfig {
        let source = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(source)
    }

    // MARK: Serialization

    /// Serialize this config back to a TOML string.
    public func serialize() -> String {
        var lines: [String] = []

        lines.append("[default]")
        lines.append("app = \(tomlString(defaultBrowser.app))")
        lines.append("profile = \(tomlString(defaultBrowser.profile))")

        for handler in handlers {
            lines.append("")
            lines.append("[[handlers]]")

            if !handler.hostnames.isEmpty {
                lines.append("hostnames = [\(handler.hostnames.map(tomlString).joined(separator: ", "))]")
            }
            if !handler.hostnameRegexps.isEmpty {
                lines.append("hostname_regexps = [\(handler.hostnameRegexps.map(tomlString).joined(separator: ", "))]")
            }
            if !handler.match.isEmpty {
                lines.append("match = [\(handler.match.map(tomlString).joined(separator: ", "))]")
            }

            lines.append("app = \(tomlString(handler.app))")
            if !handler.profile.isEmpty {
                lines.append("profile = \(tomlString(handler.profile))")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Routing

    /// Route a URL to a BrowserTarget by evaluating handlers in order.
    /// Returns the first matching handler's target, or defaultBrowser if none match.
    public func route(_ url: URL) -> BrowserTarget {
        for handler in handlers {
            if handler.matchesURL(url) {
                return BrowserTarget(app: handler.app, profile: handler.profile)
            }
        }
        return defaultBrowser
    }

    // MARK: Paths

    /// Returns the default config file path: ~/.config/hops/hops.toml
    public static func configFilePath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/hops/hops.toml"
    }
}

// MARK: - Private helpers

private func tomlString(_ value: String) -> String {
    // Escape backslashes and double-quotes, wrap in double-quotes.
    let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}
