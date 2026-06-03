import XCTest
@testable import LiteLLMUsageBarCore

final class PackageSmokeTests: XCTestCase {
    func testAppConstantsExposeGatewayURLs() {
        XCTAssertEqual(AppConstants.gatewayURL.absoluteString, "https://llm-gateway.razorpay.com")
        XCTAssertEqual(AppConstants.liteLLMUIURL.absoluteString, "https://llm-gateway.razorpay.com/ui")
        XCTAssertEqual(AppConstants.refreshInterval, 300)
        XCTAssertEqual(AppConstants.notificationThresholds, [0.5, 0.8, 1.0])
    }

    func testFixedDateProviderReturnsConfiguredDate() {
        let date = Date(timeIntervalSince1970: 1_779_984_000)
        let provider = FixedDateProvider(now: date)
        XCTAssertEqual(provider.now(), date)
    }
}
