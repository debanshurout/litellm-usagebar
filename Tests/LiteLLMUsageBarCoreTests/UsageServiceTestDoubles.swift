import Foundation
@testable import LiteLLMUsageBarCore

final class RecordingLiteLLMClient: LiteLLMClient {
    var dailyActivityResponse = DailyActivityResponse(rows: [])
    var userInfoResponse = UserInfoResponse(userBudget: nil, keyBudget: nil, userSpend: nil, currency: nil, budgetResetAt: nil)
    var error: Error?
    private(set) var dailyActivityCalls = 0
    private(set) var userInfoCalls = 0

    func fetchDailyActivity(apiKey: String, startDate: Date, endDate: Date) async throws -> DailyActivityResponse {
        dailyActivityCalls += 1
        if let error {
            throw error
        }
        return dailyActivityResponse
    }

    func fetchUserInfo(apiKey: String) async throws -> UserInfoResponse {
        userInfoCalls += 1
        if let error {
            throw error
        }
        return userInfoResponse
    }
}

final class InMemoryAPIKeyStore: APIKeyStore {
    var apiKey: String?
    private(set) var loadCount = 0

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    func loadAPIKey() throws -> String? {
        loadCount += 1
        apiKey
    }

    func saveAPIKey(_ apiKey: String) throws {
        self.apiKey = apiKey
    }

    func clearAPIKey() throws {
        apiKey = nil
    }
}

final class InMemorySnapshotStore: SnapshotStore {
    private var snapshot: UsageSnapshot?
    private(set) var savedSnapshot: UsageSnapshot?

    init(initialSnapshot: UsageSnapshot? = nil) {
        self.snapshot = initialSnapshot
    }

    func load() throws -> UsageSnapshot? {
        snapshot
    }

    func save(_ snapshot: UsageSnapshot) throws {
        self.snapshot = snapshot
        self.savedSnapshot = snapshot
    }

    func clear() throws {
        snapshot = nil
    }
}

final class RecordingBudgetNotificationService: BudgetNotificationEvaluating {
    private(set) var evaluatedSnapshots: [UsageSnapshot] = []

    func evaluate(_ snapshot: UsageSnapshot) async {
        evaluatedSnapshots.append(snapshot)
    }
}

final class NoopBudgetNotificationService: BudgetNotificationEvaluating {
    func evaluate(_ snapshot: UsageSnapshot) async {}
}
