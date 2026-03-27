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
