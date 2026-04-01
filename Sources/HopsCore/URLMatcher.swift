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
        let target = hostname + path
        let range = NSRange(target.startIndex..., in: target)
        return regex.firstMatch(in: target, range: range) != nil
    }
}

public struct QueryParamMatcher: URLMatchable {
    public let entries: [String]
    private let parsed: [(key: String, valueRegex: NSRegularExpression?)]

    public init(entries: [String]) {
        self.entries = entries
        self.parsed = entries.map { entry in
            let parts = entry.split(separator: "=", maxSplits: 1)
            let key = String(parts[0])
            if parts.count < 2 {
                return (key: key, valueRegex: nil)
            }
            let valueGlob = String(parts[1])
            if valueGlob == "*" {
                return (key: key, valueRegex: nil)
            }
            let escaped = NSRegularExpression.escapedPattern(for: valueGlob)
            let regexPattern = "^" + escaped.replacingOccurrences(of: "\\*", with: ".*") + "$"
            return (key: key, valueRegex: try? NSRegularExpression(pattern: regexPattern))
        }
    }

    public func matches(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }
        for (key, valueRegex) in parsed {
            guard let item = queryItems.first(where: { $0.name == key }) else {
                continue
            }
            if let regex = valueRegex {
                let value = item.value ?? ""
                let range = NSRange(value.startIndex..., in: value)
                if regex.firstMatch(in: value, range: range) != nil {
                    return true
                }
            } else {
                return true
            }
        }
        return false
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
