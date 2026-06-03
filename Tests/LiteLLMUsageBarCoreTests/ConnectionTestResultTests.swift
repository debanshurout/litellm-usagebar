import XCTest
@testable import LiteLLMUsageBarCore

final class ConnectionTestResultTests: XCTestCase {
    func testSuccessMessageIncludesHTTPStatus() {
        let result = ConnectionTestResult(statusCode: 200)

        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.message, "Connection successful (HTTP 200)")
    }

    func testFailureMessageIncludesHTTPStatus() {
        let result = ConnectionTestResult(statusCode: 401)

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.message, "Connection failed (HTTP 401)")
    }

    func testFailureMessageWithoutHTTPStatus() {
        let result = ConnectionTestResult(statusCode: nil)

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.message, "Connection failed (no HTTP status)")
    }
}
