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
