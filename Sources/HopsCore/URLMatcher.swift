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
