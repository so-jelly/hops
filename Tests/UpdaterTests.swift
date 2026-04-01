import XCTest
@testable import HopsCore

final class UpdaterTests: XCTestCase {
    func testNewerVersionAvailable() {
        let json = """
        {
            "tag_name": "5",
            "assets": [
                {"browser_download_url": "https://github.com/so-jelly/hops/releases/download/5/hops-5.zip"}
            ]
        }
        """.data(using: .utf8)!
        let result = Updater.parseLatestRelease(json: json, currentVersion: 4)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.version, 5)
        XCTAssertEqual(result?.downloadURL.absoluteString,
                       "https://github.com/so-jelly/hops/releases/download/5/hops-5.zip")
    }

    func testSameVersionReturnsNil() {
        let json = """
        {
            "tag_name": "4",
            "assets": [
                {"browser_download_url": "https://example.com/hops-4.zip"}
            ]
        }
        """.data(using: .utf8)!
        let result = Updater.parseLatestRelease(json: json, currentVersion: 4)
        XCTAssertNil(result)
    }

    func testOlderVersionReturnsNil() {
        let json = """
        {
            "tag_name": "3",
            "assets": [
                {"browser_download_url": "https://example.com/hops-3.zip"}
            ]
        }
        """.data(using: .utf8)!
        let result = Updater.parseLatestRelease(json: json, currentVersion: 4)
        XCTAssertNil(result)
    }

    func testMalformedJSONReturnsNil() {
        let json = "not json".data(using: .utf8)!
        let result = Updater.parseLatestRelease(json: json, currentVersion: 1)
        XCTAssertNil(result)
    }

    func testMissingAssetsReturnsNil() {
        let json = """
        {
            "tag_name": "5",
            "assets": []
        }
        """.data(using: .utf8)!
        let result = Updater.parseLatestRelease(json: json, currentVersion: 4)
        XCTAssertNil(result)
    }

    func testNonNumericTagReturnsNil() {
        let json = """
        {
            "tag_name": "v1.2.3",
            "assets": [
                {"browser_download_url": "https://example.com/hops.zip"}
            ]
        }
        """.data(using: .utf8)!
        let result = Updater.parseLatestRelease(json: json, currentVersion: 1)
        XCTAssertNil(result)
    }

    func testPicksFirstZipAsset() {
        let json = """
        {
            "tag_name": "5",
            "assets": [
                {"browser_download_url": "https://example.com/checksums.txt"},
                {"browser_download_url": "https://example.com/hops-5.zip"}
            ]
        }
        """.data(using: .utf8)!
        let result = Updater.parseLatestRelease(json: json, currentVersion: 4)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.downloadURL.absoluteString.hasSuffix(".zip"))
    }
}
