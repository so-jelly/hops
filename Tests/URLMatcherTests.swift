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

final class QueryParamMatcherTests: XCTestCase {
    func testExactKeyValueMatch() {
        let m = QueryParamMatcher(entries: ["project=FOO"])
        XCTAssertTrue(m.matches(URL(string: "https://example.com?project=FOO")!))
    }

    func testGlobValueMatch() {
        let m = QueryParamMatcher(entries: ["project=FOO*"])
        XCTAssertTrue(m.matches(URL(string: "https://example.com?project=FOO-123")!))
    }

    func testGlobValueNoMatch() {
        let m = QueryParamMatcher(entries: ["project=FOO*"])
        XCTAssertFalse(m.matches(URL(string: "https://example.com?project=BAR")!))
    }

    func testBareKeyMatchesAnyValue() {
        let m = QueryParamMatcher(entries: ["debug"])
        XCTAssertTrue(m.matches(URL(string: "https://example.com?debug=true")!))
        XCTAssertTrue(m.matches(URL(string: "https://example.com?debug=")!))
    }

    func testWildcardValueMatchesAnyValue() {
        let m = QueryParamMatcher(entries: ["env=*"])
        XCTAssertTrue(m.matches(URL(string: "https://example.com?env=prod")!))
        XCTAssertTrue(m.matches(URL(string: "https://example.com?env=staging")!))
    }

    func testNoMatchWhenParamMissing() {
        let m = QueryParamMatcher(entries: ["project=FOO"])
        XCTAssertFalse(m.matches(URL(string: "https://example.com?other=bar")!))
    }

    func testNoMatchWhenNoQueryString() {
        let m = QueryParamMatcher(entries: ["project=FOO"])
        XCTAssertFalse(m.matches(URL(string: "https://example.com/path")!))
    }

    func testMultipleEntriesOrSemantic() {
        let m = QueryParamMatcher(entries: ["project=FOO", "env=prod"])
        XCTAssertTrue(m.matches(URL(string: "https://example.com?project=FOO")!))
        XCTAssertTrue(m.matches(URL(string: "https://example.com?env=prod")!))
        XCTAssertFalse(m.matches(URL(string: "https://example.com?other=bar")!))
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
