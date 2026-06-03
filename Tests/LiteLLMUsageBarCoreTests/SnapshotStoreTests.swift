import XCTest
@testable import LiteLLMUsageBarCore

final class SnapshotStoreTests: XCTestCase {
    func testUserDefaultsSnapshotStoreRoundTripsSnapshot() throws {
        let defaults = UserDefaults(suiteName: "LiteLLMUsageBarCoreTests.\(UUID().uuidString)")!
        let store = UserDefaultsSnapshotStore(defaults: defaults)
        let snapshot = UsageSnapshot(
            monthToDateSpend: Decimal(string: "12.34")!,
            todaySpend: Decimal(string: "1.25")!,
            budget: BudgetSnapshot(limit: Decimal(50), spend: Decimal(string: "12.34")!, resetAt: nil),
            currency: "USD",
            lastUpdatedAt: ISO8601DateFormatter().date(from: "2026-06-03T12:00:00Z")!,
            periodIdentifier: "2026-06"
        )

        try store.save(snapshot)

        XCTAssertEqual(try store.load(), snapshot)
    }

    func testUserDefaultsSnapshotStoreClearsSnapshot() throws {
        let defaults = UserDefaults(suiteName: "LiteLLMUsageBarCoreTests.\(UUID().uuidString)")!
        let store = UserDefaultsSnapshotStore(defaults: defaults)
        let snapshot = UsageSnapshot(
            monthToDateSpend: Decimal(1),
            todaySpend: Decimal(1),
            budget: nil,
            currency: "USD",
            lastUpdatedAt: Date(timeIntervalSince1970: 1),
            periodIdentifier: "2026-06"
        )

        try store.save(snapshot)
        try store.clear()

        XCTAssertNil(try store.load())
    }
}
