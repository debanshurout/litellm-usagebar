import Foundation

public extension JSONDecoder {
    static var liteLLM: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: value) {
                return date
            }

            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported date: \(value)"
            )
        }
        return decoder
    }
}

public struct DailyActivityResponse: Decodable, Equatable {
    public let rows: [DailyUsageRow]

    public init(rows: [DailyUsageRow]) {
        self.rows = rows
    }

    private enum CodingKeys: String, CodingKey {
        case results
        case data
        case dailyActivity = "daily_activity"
        case activity
    }

    public init(from decoder: Decoder) throws {
        if let rows = try? [DailyUsageRow](from: decoder) {
            self.rows = rows
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rows = try container.decodeIfPresent([DailyUsageRow].self, forKey: .results) {
            self.rows = rows
            return
        }
        if let rows = try container.decodeIfPresent([DailyUsageRow].self, forKey: .data) {
            self.rows = rows
            return
        }
        if let rows = try container.decodeIfPresent([DailyUsageRow].self, forKey: .dailyActivity) {
            self.rows = rows
            return
        }
        if let rows = try container.decodeIfPresent([DailyUsageRow].self, forKey: .activity) {
            self.rows = rows
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Daily activity rows not found"
            )
        )
    }
}

public struct DailyUsageRow: Decodable, Equatable {
    public let day: String
    public let spend: Decimal
    public let promptTokens: Int?
    public let completionTokens: Int?
    public let totalTokens: Int?
    public let requestCount: Int?

    private enum CodingKeys: String, CodingKey {
        case date
        case day
        case spend
        case totalSpend = "total_spend"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case requestCount = "request_count"
        case numRequests = "num_requests"
        case metrics
    }

    public init(
        day: String,
        spend: Decimal,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        totalTokens: Int? = nil,
        requestCount: Int? = nil
    ) {
        self.day = day
        self.spend = spend
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
        self.requestCount = requestCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let metrics = try container.decodeIfPresent(DailyUsageMetrics.self, forKey: .metrics)
        self.day = try container.decodeFirstString(keys: [.date, .day])
        guard let spend = container.decodeFirstOptionalDecimal(keys: [.spend, .totalSpend]) ?? metrics?.spend else {
            throw DecodingError.keyNotFound(
                CodingKeys.spend,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Decimal not found for spend, total_spend, or metrics.spend"
                )
            )
        }
        self.spend = spend
        self.promptTokens = (try container.decodeIfPresent(Int.self, forKey: .promptTokens)) ?? metrics?.promptTokens
        self.completionTokens = (try container.decodeIfPresent(Int.self, forKey: .completionTokens)) ?? metrics?.completionTokens
        self.totalTokens = (try container.decodeIfPresent(Int.self, forKey: .totalTokens)) ?? metrics?.totalTokens
        self.requestCount = container.decodeFirstOptionalInt(keys: [.requestCount, .numRequests]) ?? metrics?.requestCount
    }
}

private struct DailyUsageMetrics: Decodable, Equatable {
    let spend: Decimal?
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
    let requestCount: Int?

    private enum CodingKeys: String, CodingKey {
        case spend
        case totalSpend = "total_spend"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case requestCount = "request_count"
        case numRequests = "num_requests"
        case apiRequests = "api_requests"
        case successfulRequests = "successful_requests"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.spend = container.decodeFirstOptionalDecimal(keys: [.spend, .totalSpend])
        self.promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
        self.completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
        self.totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
        self.requestCount = container.decodeFirstOptionalInt(keys: [.requestCount, .numRequests, .apiRequests, .successfulRequests])
    }
}

public struct UserInfoResponse: Decodable, Equatable {
    public let userBudget: Decimal?
    public let keyBudget: Decimal?
    public let userSpend: Decimal?
    public let currency: String?
    public let budgetResetAt: Date?

    public var preferredBudget: Decimal? {
        userBudget ?? keyBudget
    }

    private enum CodingKeys: String, CodingKey {
        case userInfo = "user_info"
        case keyInfo = "key_info"
        case maxBudget = "max_budget"
        case budget
        case spend
        case currency
        case budgetResetAt = "budget_reset_at"
        case budgetResetDate = "budget_reset_date"
    }

    public init(
        userBudget: Decimal?,
        keyBudget: Decimal?,
        userSpend: Decimal?,
        currency: String?,
        budgetResetAt: Date?
    ) {
        self.userBudget = userBudget
        self.keyBudget = keyBudget
        self.userSpend = userSpend
        self.currency = currency
        self.budgetResetAt = budgetResetAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let userInfo = try container.decodeIfPresent(FlexibleBudgetInfo.self, forKey: .userInfo)
        let keyInfo = try container.decodeIfPresent(FlexibleBudgetInfo.self, forKey: .keyInfo)

        self.userBudget = userInfo?.budget ?? container.decodeFirstOptionalDecimal(keys: [.maxBudget, .budget])
        self.keyBudget = keyInfo?.budget
        self.userSpend = userInfo?.spend ?? container.decodeIfPresentDecimal(forKey: .spend)
        self.currency = userInfo?.currency ?? keyInfo?.currency ?? (try? container.decodeIfPresent(String.self, forKey: .currency))
        self.budgetResetAt = userInfo?.budgetResetAt ?? keyInfo?.budgetResetAt ?? container.decodeFirstOptionalDate(keys: [.budgetResetAt, .budgetResetDate])
    }
}

private struct FlexibleBudgetInfo: Decodable, Equatable {
    let budget: Decimal?
    let spend: Decimal?
    let currency: String?
    let budgetResetAt: Date?

    private enum CodingKeys: String, CodingKey {
        case maxBudget = "max_budget"
        case budget
        case spend
        case currency
        case budgetResetAt = "budget_reset_at"
        case budgetResetDate = "budget_reset_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.budget = container.decodeFirstOptionalDecimal(keys: [.maxBudget, .budget])
        self.spend = container.decodeIfPresentDecimal(forKey: .spend)
        self.currency = try? container.decodeIfPresent(String.self, forKey: .currency)
        self.budgetResetAt = container.decodeFirstOptionalDate(keys: [.budgetResetAt, .budgetResetDate])
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(keys: [Key]) throws -> String {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                return value
            }
        }
        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "String not found for keys \(keys)"
            )
        )
    }

    func decodeFirstDecimal(keys: [Key]) throws -> Decimal {
        if let value = decodeFirstOptionalDecimal(keys: keys) {
            return value
        }
        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Decimal not found for keys \(keys)"
            )
        )
    }

    func decodeFirstOptionalDecimal(keys: [Key]) -> Decimal? {
        for key in keys {
            if let value = decodeIfPresentDecimal(forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeIfPresentDecimal(forKey key: Key) -> Decimal? {
        if let decimal = try? decodeIfPresent(Decimal.self, forKey: key) {
            return decimal
        }
        if let double = try? decodeIfPresent(Double.self, forKey: key) {
            return Decimal(double)
        }
        if let string = try? decodeIfPresent(String.self, forKey: key) {
            return Decimal(string: string)
        }
        return nil
    }

    func decodeFirstOptionalInt(keys: [Key]) -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeFirstOptionalDate(keys: [Key]) -> Date? {
        for key in keys {
            if let date = try? decodeIfPresent(Date.self, forKey: key) {
                return date
            }
        }
        return nil
    }
}
