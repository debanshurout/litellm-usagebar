import XCTest
@testable import LiteLLMUsageBarCore

final class UsageServiceTests: XCTestCase {
    @MainActor
    func testMissingAPIKeyDoesNotCallGateway() async throws {
        let keyStore = InMemoryAPIKeyStore(apiKey: nil)
        let client = RecordingLiteLLMClient()
        let service = UsageService(
            client: client,
            apiKeyStore: keyStore,
            snapshotStore: InMemorySnapshotStore(),
            notificationService: NoopBudgetNotificationService(),
            dateProvider: FixedDateProvider(now: ISO8601DateFormatter().date(from: "2026-06-03T10:00:00Z")!),
            aggregator: UsageAggregator(calendar: gregorianUTC())
        )

        await service.refresh(trigger: .manual)

        XCTAssertEqual(service.state, .missingAPIKey(stale: nil))
        XCTAssertEqual(client.dailyActivityCalls, 0)
    }

    @MainActor
    func testSuccessfulRefreshLoadsUsageSavesSnapshotAndNotifies() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-06-03T10:00:00Z")!
        let client = RecordingLiteLLMClient()
        client.dailyActivityResponse = DailyActivityResponse(rows: [
            DailyUsageRow(day: "2026-06-03", spend: Decimal(82))
        ])
        client.userInfoResponse = UserInfoResponse(userBudget: Decimal(100), keyBudget: nil, userSpend: nil, currency: "USD", budgetResetAt: nil)
        let snapshotStore = InMemorySnapshotStore()
        let notificationService = RecordingBudgetNotificationService()
        let service = UsageService(
            client: client,
            apiKeyStore: InMemoryAPIKeyStore(apiKey: "abc123"),
            snapshotStore: snapshotStore,
            notificationService: notificationService,
            dateProvider: FixedDateProvider(now: now),
            aggregator: UsageAggregator(calendar: gregorianUTC())
        )

        await service.refresh(trigger: .manual)

        XCTAssertEqual(client.dailyActivityCalls, 1)
        XCTAssertEqual(client.userInfoCalls, 1)
        XCTAssertEqual(service.state.latestSnapshot?.monthToDateSpend, Decimal(82))
        XCTAssertEqual(snapshotStore.savedSnapshot?.monthToDateSpend, Decimal(82))
        XCTAssertEqual(notificationService.evaluatedSnapshots.count, 1)
    }

    @MainActor
    func testRefreshReusesCachedAPIKeyAfterFirstLoad() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-06-03T10:00:00Z")!
        let client = RecordingLiteLLMClient()
        client.dailyActivityResponse = DailyActivityResponse(rows: [
            DailyUsageRow(day: "2026-06-03", spend: Decimal(1))
        ])
        client.userInfoResponse = UserInfoResponse(userBudget: Decimal(100), keyBudget: nil, userSpend: nil, currency: "USD", budgetResetAt: nil)
        let keyStore = InMemoryAPIKeyStore(apiKey: "abc123")
        let service = UsageService(
            client: client,
            apiKeyStore: keyStore,
            snapshotStore: InMemorySnapshotStore(),
            notificationService: NoopBudgetNotificationService(),
            dateProvider: FixedDateProvider(now: now),
            aggregator: UsageAggregator(calendar: gregorianUTC())
        )

        await service.refresh(trigger: .manual)
        await service.refresh(trigger: .manual)

        XCTAssertEqual(keyStore.loadCount, 1)
        XCTAssertEqual(client.dailyActivityCalls, 2)
        XCTAssertEqual(client.userInfoCalls, 2)
    }

    @MainActor
    func testUnauthorizedKeepsStaleSnapshot() async throws {
        let stale = UsageSnapshot(
            monthToDateSpend: Decimal(11),
            todaySpend: Decimal(1),
            budget: nil,
            currency: "USD",
            lastUpdatedAt: Date(timeIntervalSince1970: 1),
            periodIdentifier: "2026-06"
        )
        let client = RecordingLiteLLMClient()
        client.error = LiteLLMClientError.unauthorized
        let service = UsageService(
            client: client,
            apiKeyStore: InMemoryAPIKeyStore(apiKey: "bad"),
            snapshotStore: InMemorySnapshotStore(initialSnapshot: stale),
            notificationService: NoopBudgetNotificationService(),
            dateProvider: FixedDateProvider(now: ISO8601DateFormatter().date(from: "2026-06-03T10:00:00Z")!),
            aggregator: UsageAggregator(calendar: gregorianUTC())
        )

        await service.refresh(trigger: .manual)

        XCTAssertEqual(service.state, .failed(error: .unauthorized, stale: stale))
    }

    private func gregorianUTC() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
