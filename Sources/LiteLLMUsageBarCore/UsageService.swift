import Combine
import Foundation

@MainActor
public final class UsageService: ObservableObject {
    public enum RefreshTrigger {
        case timer
        case manual
    }

    @Published public private(set) var state: UsageRefreshState

    public var statePublisher: AnyPublisher<UsageRefreshState, Never> {
        $state.eraseToAnyPublisher()
    }

    private let client: LiteLLMClient
    private let apiKeyStore: APIKeyStore
    private let snapshotStore: SnapshotStore
    private let notificationService: BudgetNotificationEvaluating
    private let dateProvider: DateProvider
    private let aggregator: UsageAggregator
    private var refreshTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var refreshToken = UUID()

    public init(
        client: LiteLLMClient,
        apiKeyStore: APIKeyStore,
        snapshotStore: SnapshotStore,
        notificationService: BudgetNotificationEvaluating,
        dateProvider: DateProvider = SystemDateProvider(),
        aggregator: UsageAggregator = UsageAggregator()
    ) {
        self.client = client
        self.apiKeyStore = apiKeyStore
        self.snapshotStore = snapshotStore
        self.notificationService = notificationService
        self.dateProvider = dateProvider
        self.aggregator = aggregator
        let cached = try? snapshotStore.load()
        self.state = .loading(stale: cached ?? nil)
    }

    deinit {
        refreshTask?.cancel()
        timerTask?.cancel()
    }

    public func start() {
        Task { await refresh(trigger: .timer) }
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(AppConstants.refreshInterval * 1_000_000_000))
                await self?.refresh(trigger: .timer)
            }
        }
    }

    public func stop() {
        refreshTask?.cancel()
        timerTask?.cancel()
        refreshTask = nil
        timerTask = nil
    }

    public func refresh(trigger: RefreshTrigger) async {
        if trigger == .manual {
            refreshTask?.cancel()
        } else if refreshTask != nil {
            return
        }

        let stale = state.latestSnapshot ?? ((try? snapshotStore.load()) ?? nil)
        guard let apiKey = try? apiKeyStore.loadAPIKey(), apiKey.isEmpty == false else {
            refreshToken = UUID()
            refreshTask = nil
            DiagnosticLogger.log("refresh skipped: missing API key")
            state = .missingAPIKey(stale: stale)
            return
        }

        DiagnosticLogger.log("refresh started trigger=\(trigger)")
        state = .loading(stale: stale)
        let token = UUID()
        refreshToken = token

        let task = Task { [client, aggregator, dateProvider, snapshotStore, notificationService, weak self] in
            do {
                let now = dateProvider.now()
                let range = aggregator.currentMonthRange(containing: now)
                async let activity = client.fetchDailyActivity(apiKey: apiKey, startDate: range.start, endDate: range.end)
                async let userInfo = Self.fetchOptionalUserInfo(client: client, apiKey: apiKey)
                let snapshot = try aggregator.makeSnapshot(
                    dailyActivity: try await activity,
                    userInfo: await userInfo,
                    now: now
                )
                guard Task.isCancelled == false else {
                    return
                }
                guard await Self.isCurrentRefresh(token, service: self) else {
                    return
                }
                try? snapshotStore.save(snapshot)
                guard Task.isCancelled == false else {
                    return
                }
                guard await Self.isCurrentRefresh(token, service: self) else {
                    return
                }
                await notificationService.evaluate(snapshot)
                await MainActor.run {
                    guard Task.isCancelled == false, let self, self.refreshToken == token else {
                        return
                    }
                    DiagnosticLogger.log("refresh succeeded budgetAvailable=\(snapshot.budget != nil)")
                    self.state = .loaded(snapshot)
                }
            } catch {
                guard Task.isCancelled == false else {
                    return
                }
                await MainActor.run {
                    guard let self, self.refreshToken == token else {
                        return
                    }
                    let mappedError = Self.map(error)
                    DiagnosticLogger.log("refresh failed mappedError=\(mappedError) underlying=\(error)")
                    self.state = .failed(error: mappedError, stale: stale)
                }
            }
        }

        refreshTask = task
        await task.value
        if refreshToken == token {
            refreshTask = nil
        }
    }

    public func reloadAfterKeyChange() {
        Task { await refresh(trigger: .manual) }
    }

    private static func fetchOptionalUserInfo(client: LiteLLMClient, apiKey: String) async -> UserInfoResponse {
        do {
            return try await client.fetchUserInfo(apiKey: apiKey)
        } catch {
            DiagnosticLogger.log("user info unavailable; continuing without budget: \(error)")
            return UserInfoResponse(userBudget: nil, keyBudget: nil, userSpend: nil, currency: nil, budgetResetAt: nil)
        }
    }

    private static func isCurrentRefresh(_ token: UUID, service: UsageService?) async -> Bool {
        await MainActor.run {
            guard let service else {
                return false
            }
            return service.refreshToken == token
        }
    }

    private static func map(_ error: Error) -> UsageRefreshError {
        if let clientError = error as? LiteLLMClientError {
            switch clientError {
            case .unauthorized:
                return .unauthorized
            case .server:
                return .networkOrServer
            case .malformedResponse:
                return .malformedResponse
            }
        }
        if error is DecodingError {
            return .malformedResponse
        }
        return .networkOrServer
    }
}
