import Foundation

public struct UsageAggregator {
    private let calendar: Calendar
    private let dayFormatter: DateFormatter

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = formatter
    }

    public func makeSnapshot(
        dailyActivity: DailyActivityResponse,
        userInfo: UserInfoResponse,
        now: Date
    ) throws -> UsageSnapshot {
        let monthRows = dailyActivity.rows.filter { row in
            guard let date = dayFormatter.date(from: row.day) else {
                return false
            }
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
                && calendar.isDate(date, equalTo: now, toGranularity: .year)
        }

        let todayKey = dayFormatter.string(from: now)
        let monthToDateSpend = monthRows.reduce(Decimal.zero) { $0 + $1.spend }
        let todaySpend = monthRows.first(where: { $0.day == todayKey })?.spend ?? Decimal.zero
        let currency = userInfo.currency ?? "USD"
        let budget = userInfo.preferredBudget.map {
            BudgetSnapshot(limit: $0, spend: monthToDateSpend, resetAt: userInfo.budgetResetAt)
        }

        return UsageSnapshot(
            monthToDateSpend: monthToDateSpend,
            todaySpend: todaySpend,
            budget: budget,
            currency: currency,
            lastUpdatedAt: now,
            periodIdentifier: Self.periodIdentifier(for: userInfo.budgetResetAt, now: now, calendar: calendar)
        )
    }

    public func currentMonthRange(containing date: Date) -> (start: Date, end: Date) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
        return (start, end)
    }

    private static func periodIdentifier(for resetAt: Date?, now: Date, calendar: Calendar) -> String {
        if let resetAt {
            return ISO8601DateFormatter().string(from: resetAt)
        }
        let components = calendar.dateComponents([.year, .month], from: now)
        return String(format: "%04d-%02d", components.year!, components.month!)
    }
}
