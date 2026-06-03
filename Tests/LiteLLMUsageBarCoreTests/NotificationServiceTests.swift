import XCTest
@testable import LiteLLMUsageBarCore

final class NotificationServiceTests: XCTestCase {
    func testThresholdsAreSentOncePerPeriod() async throws {
        let center = RecordingNotificationCenter()
        let store = InMemoryThresholdStore()
        let service = BudgetNotificationService(center: center, thresholdStore: store)
        let snapshot = UsageSnapshot(
            monthToDateSpend: Decimal(82),
            todaySpend: Decimal(4),
            budget: BudgetSnapshot(limit: Decimal(100), spend: Decimal(82), resetAt: nil),
            currency: "USD",
            lastUpdatedAt: Date(timeIntervalSince1970: 1),
            periodIdentifier: "2026-06"
        )

        await service.evaluate(snapshot)
        await service.evaluate(snapshot)

        XCTAssertEqual(center.deliveredTitles, [
            "LiteLLM budget 50% used",
            "LiteLLM budget 80% used"
        ])
        XCTAssertEqual(store.sentThresholds(for: "2026-06"), [0.5, 0.8])
    }

    func testNoNotificationWhenBudgetUnavailable() async throws {
        let center = RecordingNotificationCenter()
        let store = InMemoryThresholdStore()
        let service = BudgetNotificationService(center: center, thresholdStore: store)
        let snapshot = UsageSnapshot(
            monthToDateSpend: Decimal(82),
            todaySpend: Decimal(4),
            budget: nil,
            currency: "USD",
            lastUpdatedAt: Date(timeIntervalSince1970: 1),
            periodIdentifier: "2026-06"
        )

        await service.evaluate(snapshot)

        XCTAssertTrue(center.deliveredTitles.isEmpty)
        XCTAssertTrue(store.sentThresholds(for: "2026-06").isEmpty)
    }
}
