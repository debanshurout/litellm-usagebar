import Foundation

public struct UsageSnapshot: Codable, Equatable {
    public let monthToDateSpend: Decimal
    public let todaySpend: Decimal
    public let budget: BudgetSnapshot?
    public let currency: String
    public let lastUpdatedAt: Date
    public let periodIdentifier: String

    public init(
        monthToDateSpend: Decimal,
        todaySpend: Decimal,
        budget: BudgetSnapshot?,
        currency: String,
        lastUpdatedAt: Date,
        periodIdentifier: String
    ) {
        self.monthToDateSpend = monthToDateSpend
        self.todaySpend = todaySpend
        self.budget = budget
        self.currency = currency
        self.lastUpdatedAt = lastUpdatedAt
        self.periodIdentifier = periodIdentifier
    }
}

public struct BudgetSnapshot: Codable, Equatable {
    public let limit: Decimal
    public let percentUsed: Double
    public let resetAt: Date?

    public init(limit: Decimal, spend: Decimal, resetAt: Date?) {
        self.limit = limit
        if limit > Decimal.zero {
            self.percentUsed = NSDecimalNumber(decimal: spend / limit).doubleValue
        } else {
            self.percentUsed = 0
        }
        self.resetAt = resetAt
    }
}

public enum UsageRefreshError: Error, Equatable {
    case missingAPIKey
    case unauthorized
    case networkOrServer
    case malformedResponse
}

public enum UsageRefreshState: Equatable {
    case missingAPIKey(stale: UsageSnapshot?)
    case loading(stale: UsageSnapshot?)
    case loaded(UsageSnapshot)
    case failed(error: UsageRefreshError, stale: UsageSnapshot?)

    public var latestSnapshot: UsageSnapshot? {
        switch self {
        case .missingAPIKey(let stale), .loading(let stale), .failed(_, let stale):
            return stale
        case .loaded(let snapshot):
            return snapshot
        }
    }
}
