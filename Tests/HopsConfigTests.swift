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

    func testParseQueryParams() throws {
        let toml = """
        [default]
        app = "Safari"

        [[handlers]]
        query_params = ["project=FOO*", "env=prod"]
        app = "Google Chrome"
        profile = "Work"
        """
        let config = try HopsConfig.parse(toml)
        XCTAssertEqual(config.handlers[0].queryParams, ["project=FOO*", "env=prod"])
    }

    func testRouteByQueryParam() throws {
        let toml = """
        [default]
        app = "Safari"

        [[handlers]]
        query_params = ["project=FOO*"]
        app = "Google Chrome"
        profile = "Work"
        """
        let config = try HopsConfig.parse(toml)
        let target = config.route(URL(string: "https://console.cloud.google.com?project=FOO-123")!)
        XCTAssertEqual(target.app, "Google Chrome")
        XCTAssertEqual(target.profile, "Work")
    }

    func testSerializeQueryParams() throws {
        let toml = """
        [default]
        app = "Safari"

        [[handlers]]
        query_params = ["project=FOO*"]
        app = "Google Chrome"
        profile = "Work"
        """
        let config = try HopsConfig.parse(toml)
        let serialized = config.serialize()
        let reparsed = try HopsConfig.parse(serialized)
        XCTAssertEqual(reparsed.handlers[0].queryParams, ["project=FOO*"])
    }

    func testRouteUnknownDomainDefault() throws {
        let config = try HopsConfig.parse(testConfig)
        let target = config.route(URL(string: "https://example.com/page")!)
        XCTAssertEqual(target.profile, "Person 1")
        XCTAssertEqual(target.app, "Google Chrome")
    }
}
