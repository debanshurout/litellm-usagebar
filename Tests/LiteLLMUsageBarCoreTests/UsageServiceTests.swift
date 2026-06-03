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
    func testSuccessfulDailyActivityStillLoadsWhenUserInfoIsUnavailable() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-06-03T10:00:00Z")!
        let client = RecordingLiteLLMClient()
        client.dailyActivityResponse = DailyActivityResponse(rows: [
            DailyUsageRow(day: "2026-06-03", spend: Decimal(82))
        ])
        client.userInfoError = LiteLLMClientError.unauthorized
        let snapshotStore = InMemorySnapshotStore()
        let service = UsageService(
            client: client,
            apiKeyStore: InMemoryAPIKeyStore(apiKey: "scoped-key"),
            snapshotStore: snapshotStore,
            notificationService: NoopBudgetNotificationService(),
            dateProvider: FixedDateProvider(now: now),
            aggregator: UsageAggregator(calendar: gregorianUTC())
        )

        await service.refresh(trigger: .manual)

        XCTAssertEqual(service.state.latestSnapshot?.monthToDateSpend, Decimal(82))
        XCTAssertNil(service.state.latestSnapshot?.budget)
        XCTAssertEqual(snapshotStore.savedSnapshot?.monthToDateSpend, Decimal(82))
    }

    @MainActor
    func testMissingAPIKeyInvalidatesInFlightRefresh() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-06-03T10:00:00Z")!
        let client = QueuedActivityLiteLLMClient()
        let keyStore = InMemoryAPIKeyStore(apiKey: "abc123")
        let snapshotStore = InMemorySnapshotStore()
        let notificationService = RecordingBudgetNotificationService()
        let service = UsageService(
            client: client,
            apiKeyStore: keyStore,
            snapshotStore: snapshotStore,
            notificationService: notificationService,
            dateProvider: FixedDateProvider(now: now),
            aggregator: UsageAggregator(calendar: gregorianUTC())
        )
        let firstRefresh = Task { await service.refresh(trigger: .manual) }
        await waitForActivityRequests(client, count: 1)

        keyStore.apiKey = nil
        await service.refresh(trigger: .manual)
        client.resolveNextActivity(with: DailyActivityResponse(rows: [
            DailyUsageRow(day: "2026-06-03", spend: Decimal(82))
        ]))
        await firstRefresh.value

        XCTAssertEqual(service.state, .missingAPIKey(stale: nil))
        XCTAssertNil(snapshotStore.savedSnapshot)
        XCTAssertTrue(notificationService.evaluatedSnapshots.isEmpty)
    }

    @MainActor
    func testSupersededRefreshDoesNotSaveSnapshotOrNotify() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-06-03T10:00:00Z")!
        let client = QueuedActivityLiteLLMClient()
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
        let staleRefresh = Task { await service.refresh(trigger: .timer) }
        await waitForActivityRequests(client, count: 1)

        let currentRefresh = Task { await service.refresh(trigger: .manual) }
        await waitForActivityRequests(client, count: 2)
        client.resolveLatestActivity(with: DailyActivityResponse(rows: [
            DailyUsageRow(day: "2026-06-03", spend: Decimal(2))
        ]))
        await currentRefresh.value

        client.resolveNextActivity(with: DailyActivityResponse(rows: [
            DailyUsageRow(day: "2026-06-03", spend: Decimal(1))
        ]))
        await staleRefresh.value

        XCTAssertEqual(snapshotStore.savedSnapshot?.monthToDateSpend, Decimal(2))
        XCTAssertEqual(notificationService.evaluatedSnapshots.map(\.monthToDateSpend), [Decimal(2)])
        XCTAssertEqual(service.state.latestSnapshot?.monthToDateSpend, Decimal(2))
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

    private func waitForActivityRequests(_ client: QueuedActivityLiteLLMClient, count: Int) async {
        while client.activityRequestCount < count {
            await Task.yield()
        }
    }
}
