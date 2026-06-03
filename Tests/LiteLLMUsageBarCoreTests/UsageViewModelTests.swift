import XCTest
@testable import LiteLLMUsageBarCore

final class UsageViewModelTests: XCTestCase {
    func testLoadedStateFormatsTitleAndMenuRows() {
        let snapshot = UsageSnapshot(
            monthToDateSpend: Decimal(string: "42.1")!,
            todaySpend: Decimal(string: "3.75")!,
            budget: BudgetSnapshot(limit: Decimal(100), spend: Decimal(string: "42.1")!, resetAt: nil),
            currency: "USD",
            lastUpdatedAt: ISO8601DateFormatter().date(from: "2026-06-03T12:30:00Z")!,
            periodIdentifier: "2026-06"
        )

        let display = UsageDisplayState.make(
            from: .loaded(snapshot),
            now: ISO8601DateFormatter().date(from: "2026-06-03T12:35:00Z")!
        )

        XCTAssertEqual(display.menuBarTitle, "$42.10 MTD")
        XCTAssertEqual(display.monthToDateText, "Month to date: $42.10")
        XCTAssertEqual(display.todayText, "Today: $3.75")
        XCTAssertEqual(display.budgetText, "Budget: $42.10 of $100.00 (42%)")
        XCTAssertEqual(display.lastUpdatedText, "Updated 5 min ago")
        XCTAssertNil(display.messageText)
    }

    func testMissingKeyAndUnavailableStates() {
        let now = ISO8601DateFormatter().date(from: "2026-06-03T12:35:00Z")!

        let missing = UsageDisplayState.make(from: .missingAPIKey(stale: nil), now: now)
        XCTAssertEqual(missing.menuBarTitle, "Set API Key")
        XCTAssertEqual(missing.messageText, "Enter a LiteLLM API key in Settings.")

        let unavailable = UsageDisplayState.make(from: .failed(error: .malformedResponse, stale: nil), now: now)
        XCTAssertEqual(unavailable.menuBarTitle, "Usage unavailable")
        XCTAssertEqual(unavailable.messageText, "Usage data format changed")
    }

    func testFailedStateKeepsStaleMenuBarSpend() {
        let stale = UsageSnapshot(
            monthToDateSpend: Decimal(string: "18.5")!,
            todaySpend: Decimal(string: "1.25")!,
            budget: nil,
            currency: "USD",
            lastUpdatedAt: ISO8601DateFormatter().date(from: "2026-06-03T12:00:00Z")!,
            periodIdentifier: "2026-06"
        )
        let now = ISO8601DateFormatter().date(from: "2026-06-03T12:35:00Z")!

        let display = UsageDisplayState.make(from: .failed(error: .networkOrServer, stale: stale), now: now)

        XCTAssertEqual(display.menuBarTitle, "$18.50 MTD")
        XCTAssertEqual(display.budgetText, "Budget unavailable")
        XCTAssertEqual(display.messageText, "Last refresh failed")
        XCTAssertEqual(display.lastUpdatedText, "Updated 35 min ago")
    }
}
