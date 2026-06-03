import XCTest
@testable import LiteLLMUsageBarCore

final class UsageAggregatorTests: XCTestCase {
    func testAggregatesMonthToDateAndTodaySpend() throws {
        let calendar = gregorianUTC()
        let today = ISO8601DateFormatter().date(from: "2026-06-03T10:30:00Z")!
        let rows = [
            DailyUsageRow(day: "2026-05-31", spend: Decimal(string: "9.99")!),
            DailyUsageRow(day: "2026-06-01", spend: Decimal(string: "2.00")!, requestCount: 1),
            DailyUsageRow(day: "2026-06-02", spend: Decimal(string: "3.50")!, requestCount: 2),
            DailyUsageRow(day: "2026-06-03", spend: Decimal(string: "4.25")!, requestCount: 3)
        ]

        let snapshot = try UsageAggregator(calendar: calendar).makeSnapshot(
            dailyActivity: DailyActivityResponse(rows: rows),
            userInfo: UserInfoResponse(
                userBudget: Decimal(20),
                keyBudget: Decimal(10),
                userSpend: Decimal(string: "42.10"),
                currency: "USD",
                budgetResetAt: ISO8601DateFormatter().date(from: "2026-07-01T00:00:00Z")
            ),
            now: today
        )

        XCTAssertEqual(snapshot.monthToDateSpend, Decimal(string: "9.75")!)
        XCTAssertEqual(snapshot.todaySpend, Decimal(string: "4.25")!)
        XCTAssertEqual(snapshot.budget?.limit, Decimal(20))
        XCTAssertEqual(snapshot.budget?.percentUsed ?? 0, 0.4875, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertEqual(snapshot.periodIdentifier, "2026-07-01T00:00:00Z")
    }

    func testBudgetUnavailableWhenNoBudgetReturned() throws {
        let calendar = gregorianUTC()
        let now = ISO8601DateFormatter().date(from: "2026-06-03T10:30:00Z")!

        let snapshot = try UsageAggregator(calendar: calendar).makeSnapshot(
            dailyActivity: DailyActivityResponse(rows: [
                DailyUsageRow(day: "2026-06-03", spend: Decimal(string: "4.25")!)
            ]),
            userInfo: UserInfoResponse(userBudget: nil, keyBudget: nil, userSpend: nil, currency: nil, budgetResetAt: nil),
            now: now
        )

        XCTAssertNil(snapshot.budget)
        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertEqual(snapshot.periodIdentifier, "2026-06")
    }

    private func gregorianUTC() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
