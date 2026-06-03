import Foundation

public struct UsageDisplayState: Equatable {
    public let menuBarTitle: String
    public let headerText: String
    public let monthToDateText: String
    public let todayText: String
    public let budgetText: String
    public let lastUpdatedText: String
    public let messageText: String?
    public let canRefresh: Bool

    public static func make(from state: UsageRefreshState, now: Date) -> UsageDisplayState {
        let snapshot = state.latestSnapshot
        let formatter = UsageFormatter()

        let title: String
        switch state {
        case .missingAPIKey where snapshot == nil:
            title = "Set API Key"
        case .loading where snapshot == nil:
            title = "Usage..."
        case .failed where snapshot == nil:
            title = "Usage unavailable"
        default:
            title = snapshot.map { formatter.menuBarTitle(for: $0) } ?? "Usage unavailable"
        }

        let message: String?
        switch state {
        case .missingAPIKey:
            message = "Enter a LiteLLM API key in Settings."
        case .failed(let error, _):
            message = formatter.message(for: error)
        case .loading(let stale) where stale != nil:
            message = "Refreshing usage..."
        default:
            message = nil
        }

        return UsageDisplayState(
            menuBarTitle: title,
            headerText: "LiteLLM Usage",
            monthToDateText: snapshot.map { "Month to date: \(formatter.money($0.monthToDateSpend, currency: $0.currency))" } ?? "Month to date: --",
            todayText: snapshot.map { "Today: \(formatter.money($0.todaySpend, currency: $0.currency))" } ?? "Today: --",
            budgetText: snapshot.map { formatter.budgetText(for: $0) } ?? "Budget unavailable",
            lastUpdatedText: snapshot.map { formatter.relativeUpdatedText(lastUpdatedAt: $0.lastUpdatedAt, now: now) } ?? "Never updated",
            messageText: message,
            canRefresh: true
        )
    }
}

public struct UsageFormatter {
    private let currencyFormatter: NumberFormatter

    public init() {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positiveFormat = "¤#,##0.00"
        formatter.negativeFormat = "-¤#,##0.00"
        self.currencyFormatter = formatter
    }

    public func menuBarTitle(for snapshot: UsageSnapshot) -> String {
        "\(money(snapshot.monthToDateSpend, currency: snapshot.currency)) MTD"
    }

    public func budgetText(for snapshot: UsageSnapshot) -> String {
        guard let budget = snapshot.budget else {
            return "Budget unavailable"
        }
        let percent = Int((budget.percentUsed * 100).rounded())
        return "Budget: \(money(snapshot.monthToDateSpend, currency: snapshot.currency)) of \(money(budget.limit, currency: snapshot.currency)) (\(percent)%)"
    }

    public func money(_ value: Decimal, currency: String) -> String {
        currencyFormatter.currencyCode = currency
        if currency == "USD" {
            currencyFormatter.currencySymbol = "$"
        }
        return currencyFormatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }

    public func relativeUpdatedText(lastUpdatedAt: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(lastUpdatedAt)))
        if seconds < 60 {
            return "Updated just now"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "Updated \(minutes) min ago"
        }
        let hours = minutes / 60
        return "Updated \(hours) hr ago"
    }

    public func message(for error: UsageRefreshError) -> String {
        switch error {
        case .missingAPIKey:
            return "Enter a LiteLLM API key in Settings."
        case .unauthorized:
            return "API key invalid or unauthorized"
        case .networkOrServer:
            return "Last refresh failed"
        case .malformedResponse:
            return "Usage data format changed"
        }
    }
}
