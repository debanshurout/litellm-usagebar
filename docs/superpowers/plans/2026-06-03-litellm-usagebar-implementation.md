# LiteLLM UsageBar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that shows current-user LiteLLM month-to-date spend, daily spend, budget progress, refresh status, settings, and budget-threshold notifications.

**Architecture:** Use a Swift Package with a testable `LiteLLMUsageBarCore` library and a small `LiteLLMUsageBar` AppKit/SwiftUI executable. Keep gateway decoding, aggregation, refresh orchestration, storage, notification deduping, and display formatting in the core target; keep `NSStatusItem`, settings window, and app lifecycle in the executable target.

**Tech Stack:** Swift 5.9, Swift Package Manager, AppKit, SwiftUI, UserNotifications, Security framework, XCTest.

---

## File Structure

- Create `Package.swift`: package manifest with core library, menu bar executable, and XCTest target.
- Create `Sources/LiteLLMUsageBarCore/AppConstants.swift`: gateway URL, UI URL, polling interval, Keychain service/account names, notification thresholds.
- Create `Sources/LiteLLMUsageBarCore/DateProvider.swift`: injectable clock for deterministic tests.
- Create `Sources/LiteLLMUsageBarCore/LiteLLMModels.swift`: DTOs and resilient decoding for `/user/daily/activity` and `/user/info`.
- Create `Sources/LiteLLMUsageBarCore/LiteLLMClient.swift`: protocol plus `URLSession` implementation with `x-litellm-api-key: Bearer <api-key>`.
- Create `Sources/LiteLLMUsageBarCore/UsageModels.swift`: domain models for budgets, snapshots, refresh errors, and display state.
- Create `Sources/LiteLLMUsageBarCore/UsageAggregator.swift`: month-to-date, today, and budget calculation.
- Create `Sources/LiteLLMUsageBarCore/UsageViewModel.swift`: display-ready strings and state transitions.
- Create `Sources/LiteLLMUsageBarCore/KeychainStore.swift`: protocol plus Security framework implementation for API key storage.
- Create `Sources/LiteLLMUsageBarCore/SnapshotStore.swift`: protocol plus `UserDefaults` persistence for the last successful snapshot.
- Create `Sources/LiteLLMUsageBarCore/NotificationService.swift`: threshold calculation, persistence, authorization status, and macOS notification delivery.
- Create `Sources/LiteLLMUsageBarCore/UsageService.swift`: refresh coordination, manual refresh precedence, cache updates, and service state.
- Create `Sources/LiteLLMUsageBar/main.swift`: `NSApplication` bootstrap with accessory activation policy.
- Create `Sources/LiteLLMUsageBar/AppDelegate.swift`: object graph assembly and app lifecycle.
- Create `Sources/LiteLLMUsageBar/StatusBarController.swift`: `NSStatusItem`, title updates, click menu, and actions.
- Create `Sources/LiteLLMUsageBar/SettingsWindowController.swift`: settings window ownership.
- Create `Sources/LiteLLMUsageBar/SettingsView.swift`: SwiftUI API-key management and notification status UI.
- Create `Tests/LiteLLMUsageBarCoreTests/LiteLLMModelsTests.swift`: API response decoding tests.
- Create `Tests/LiteLLMUsageBarCoreTests/UsageAggregatorTests.swift`: spend aggregation and budget tests.
- Create `Tests/LiteLLMUsageBarCoreTests/UsageViewModelTests.swift`: title and menu formatting tests.
- Create `Tests/LiteLLMUsageBarCoreTests/NotificationServiceTests.swift`: threshold deduping tests.
- Create `Tests/LiteLLMUsageBarCoreTests/UsageServiceTests.swift`: refresh, stale cache, unauthorized, and manual refresh behavior tests.

---

### Task 1: Swift Package Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/LiteLLMUsageBarCore/AppConstants.swift`
- Create: `Sources/LiteLLMUsageBarCore/DateProvider.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/PackageSmokeTests.swift`

- [ ] **Step 1: Write the failing smoke test**

Create `Tests/LiteLLMUsageBarCoreTests/PackageSmokeTests.swift`:

```swift
import XCTest
@testable import LiteLLMUsageBarCore

final class PackageSmokeTests: XCTestCase {
    func testAppConstantsExposeGatewayURLs() {
        XCTAssertEqual(AppConstants.gatewayURL.absoluteString, "https://llm-gateway.razorpay.com")
        XCTAssertEqual(AppConstants.liteLLMUIURL.absoluteString, "https://llm-gateway.razorpay.com/ui")
        XCTAssertEqual(AppConstants.refreshInterval, 300)
        XCTAssertEqual(AppConstants.notificationThresholds, [0.5, 0.8, 1.0])
    }

    func testFixedDateProviderReturnsConfiguredDate() {
        let date = Date(timeIntervalSince1970: 1_779_984_000)
        let provider = FixedDateProvider(now: date)
        XCTAssertEqual(provider.now(), date)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
swift test --filter PackageSmokeTests
```

Expected: FAIL because `Package.swift` and `LiteLLMUsageBarCore` do not exist yet.

- [ ] **Step 3: Create package manifest**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiteLLMUsageBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LiteLLMUsageBarCore", targets: ["LiteLLMUsageBarCore"]),
        .executable(name: "LiteLLMUsageBar", targets: ["LiteLLMUsageBar"])
    ],
    targets: [
        .target(
            name: "LiteLLMUsageBarCore",
            dependencies: []
        ),
        .executableTarget(
            name: "LiteLLMUsageBar",
            dependencies: ["LiteLLMUsageBarCore"]
        ),
        .testTarget(
            name: "LiteLLMUsageBarCoreTests",
            dependencies: ["LiteLLMUsageBarCore"]
        )
    ]
)
```

- [ ] **Step 4: Create core constants and clock**

Create `Sources/LiteLLMUsageBarCore/AppConstants.swift`:

```swift
import Foundation

public enum AppConstants {
    public static let gatewayURL = URL(string: "https://llm-gateway.razorpay.com")!
    public static let liteLLMUIURL = URL(string: "https://llm-gateway.razorpay.com/ui")!
    public static let refreshInterval: TimeInterval = 5 * 60
    public static let notificationThresholds: [Double] = [0.5, 0.8, 1.0]
    public static let keychainService = "com.razorpay.litellm-usagebar"
    public static let keychainAccount = "litellm-api-key"
    public static let snapshotDefaultsKey = "lastSuccessfulUsageSnapshot"
    public static let thresholdDefaultsKey = "sentBudgetThresholds"
}
```

Create `Sources/LiteLLMUsageBarCore/DateProvider.swift`:

```swift
import Foundation

public protocol DateProvider {
    func now() -> Date
}

public struct SystemDateProvider: DateProvider {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public struct FixedDateProvider: DateProvider {
    private let value: Date

    public init(now: Date) {
        self.value = now
    }

    public func now() -> Date {
        value
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run:

```bash
swift test --filter PackageSmokeTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/LiteLLMUsageBarCore/AppConstants.swift Sources/LiteLLMUsageBarCore/DateProvider.swift Tests/LiteLLMUsageBarCoreTests/PackageSmokeTests.swift
git commit -m "chore: scaffold litellm usagebar package"
```

---

### Task 2: LiteLLM API Decoding

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/LiteLLMModels.swift`
- Create: `Sources/LiteLLMUsageBarCore/LiteLLMClient.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/LiteLLMModelsTests.swift`

- [ ] **Step 1: Write failing decoding tests**

Create `Tests/LiteLLMUsageBarCoreTests/LiteLLMModelsTests.swift`:

```swift
import XCTest
@testable import LiteLLMUsageBarCore

final class LiteLLMModelsTests: XCTestCase {
    func testDecodesDailyActivityEnvelope() throws {
        let json = """
        {
          "results": [
            {
              "date": "2026-06-01",
              "spend": 2.15,
              "prompt_tokens": 1000,
              "completion_tokens": 250,
              "total_tokens": 1250,
              "request_count": 4
            },
            {
              "date": "2026-06-02",
              "total_spend": 3.85,
              "num_requests": 7
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(DailyActivityResponse.self, from: json)

        XCTAssertEqual(response.rows.count, 2)
        XCTAssertEqual(response.rows[0].day, "2026-06-01")
        XCTAssertEqual(response.rows[0].spend, Decimal(string: "2.15"))
        XCTAssertEqual(response.rows[0].promptTokens, 1000)
        XCTAssertEqual(response.rows[0].completionTokens, 250)
        XCTAssertEqual(response.rows[0].totalTokens, 1250)
        XCTAssertEqual(response.rows[0].requestCount, 4)
        XCTAssertEqual(response.rows[1].spend, Decimal(string: "3.85"))
        XCTAssertEqual(response.rows[1].requestCount, 7)
    }

    func testDecodesDailyActivityArray() throws {
        let json = """
        [
          { "date": "2026-06-03", "spend": 1.25, "request_count": 2 }
        ]
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(DailyActivityResponse.self, from: json)

        XCTAssertEqual(response.rows.count, 1)
        XCTAssertEqual(response.rows[0].day, "2026-06-03")
        XCTAssertEqual(response.rows[0].spend, Decimal(string: "1.25"))
        XCTAssertEqual(response.rows[0].requestCount, 2)
    }

    func testDecodesUserInfoBudgetFromUserThenKey() throws {
        let json = """
        {
          "user_info": {
            "max_budget": 100,
            "spend": 42.1,
            "budget_reset_at": "2026-07-01T00:00:00Z",
            "currency": "USD"
          },
          "key_info": {
            "max_budget": 75
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(UserInfoResponse.self, from: json)

        XCTAssertEqual(response.preferredBudget, Decimal(100))
        XCTAssertEqual(response.userSpend, Decimal(string: "42.1"))
        XCTAssertEqual(response.currency, "USD")
        XCTAssertEqual(ISO8601DateFormatter().string(from: response.budgetResetAt!), "2026-07-01T00:00:00Z")
    }

    func testDecodesUserInfoBudgetFromKeyWhenUserBudgetMissing() throws {
        let json = """
        {
          "user_info": {
            "spend": 12.4
          },
          "key_info": {
            "budget": 25
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.liteLLM.decode(UserInfoResponse.self, from: json)

        XCTAssertEqual(response.preferredBudget, Decimal(25))
        XCTAssertEqual(response.userSpend, Decimal(string: "12.4"))
        XCTAssertNil(response.budgetResetAt)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter LiteLLMModelsTests
```

Expected: FAIL because `DailyActivityResponse`, `UserInfoResponse`, and `JSONDecoder.liteLLM` are not defined.

- [ ] **Step 3: Add LiteLLM DTOs and decoder helpers**

Create `Sources/LiteLLMUsageBarCore/LiteLLMModels.swift`:

```swift
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
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date: \(value)")
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
            DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Daily activity rows not found")
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
        self.day = try container.decodeFirstString(keys: [.date, .day])
        self.spend = try container.decodeFirstDecimal(keys: [.spend, .totalSpend])
        self.promptTokens = try container.decodeIfPresent(Int.self, forKey: .promptTokens)
        self.completionTokens = try container.decodeIfPresent(Int.self, forKey: .completionTokens)
        self.totalTokens = try container.decodeIfPresent(Int.self, forKey: .totalTokens)
        self.requestCount = try container.decodeFirstOptionalInt(keys: [.requestCount, .numRequests])
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

        self.userBudget = userInfo?.budget ?? try container.decodeFirstOptionalDecimal(keys: [.maxBudget, .budget])
        self.keyBudget = keyInfo?.budget
        self.userSpend = userInfo?.spend ?? try container.decodeIfPresentDecimal(forKey: .spend)
        self.currency = userInfo?.currency ?? keyInfo?.currency ?? try container.decodeIfPresent(String.self, forKey: .currency)
        self.budgetResetAt = userInfo?.budgetResetAt ?? keyInfo?.budgetResetAt ?? try container.decodeFirstOptionalDate(keys: [.budgetResetAt, .budgetResetDate])
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
        self.budget = try container.decodeFirstOptionalDecimal(keys: [.maxBudget, .budget])
        self.spend = try container.decodeIfPresentDecimal(forKey: .spend)
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency)
        self.budgetResetAt = try container.decodeFirstOptionalDate(keys: [.budgetResetAt, .budgetResetDate])
    }
}

private extension KeyedDecodingContainer {
    func decodeFirstString(keys: [Key]) throws -> String {
        for key in keys {
            if let value = try decodeIfPresent(String.self, forKey: key) {
                return value
            }
        }
        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(codingPath: codingPath, debugDescription: "String not found for keys \(keys)")
        )
    }

    func decodeFirstDecimal(keys: [Key]) throws -> Decimal {
        if let value = try decodeFirstOptionalDecimal(keys: keys) {
            return value
        }
        throw DecodingError.keyNotFound(
            keys[0],
            DecodingError.Context(codingPath: codingPath, debugDescription: "Decimal not found for keys \(keys)")
        )
    }

    func decodeFirstOptionalDecimal(keys: [Key]) throws -> Decimal? {
        for key in keys {
            if let value = try decodeIfPresentDecimal(forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeIfPresentDecimal(forKey key: Key) throws -> Decimal? {
        if let decimal = try decodeIfPresent(Decimal.self, forKey: key) {
            return decimal
        }
        if let double = try decodeIfPresent(Double.self, forKey: key) {
            return Decimal(double)
        }
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return Decimal(string: string)
        }
        return nil
    }

    func decodeFirstOptionalInt(keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try decodeIfPresent(Int.self, forKey: key) {
                return value
            }
        }
        return nil
    }

    func decodeFirstOptionalDate(keys: [Key]) throws -> Date? {
        for key in keys {
            if let date = try decodeIfPresent(Date.self, forKey: key) {
                return date
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Add LiteLLM client protocol and URLSession implementation**

Create `Sources/LiteLLMUsageBarCore/LiteLLMClient.swift`:

```swift
import Foundation

public protocol LiteLLMClient {
    func fetchDailyActivity(apiKey: String, startDate: Date, endDate: Date) async throws -> DailyActivityResponse
    func fetchUserInfo(apiKey: String) async throws -> UserInfoResponse
}

public enum LiteLLMClientError: Error, Equatable {
    case unauthorized
    case server(statusCode: Int)
    case malformedResponse
}

public final class URLSessionLiteLLMClient: LiteLLMClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let calendar: Calendar

    public init(
        baseURL: URL = AppConstants.gatewayURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .liteLLM,
        calendar: Calendar = Calendar.current
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.calendar = calendar
    }

    public func fetchDailyActivity(apiKey: String, startDate: Date, endDate: Date) async throws -> DailyActivityResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("user/daily/activity"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: Self.dayFormatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: Self.dayFormatter.string(from: endDate))
        ]
        return try await get(components.url!, apiKey: apiKey, as: DailyActivityResponse.self)
    }

    public func fetchUserInfo(apiKey: String) async throws -> UserInfoResponse {
        try await get(baseURL.appendingPathComponent("user/info"), apiKey: apiKey, as: UserInfoResponse.self)
    }

    private func get<T: Decodable>(_ url: URL, apiKey: String, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-litellm-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LiteLLMClientError.malformedResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw LiteLLMClientError.malformedResponse
            }
        case 401, 403:
            throw LiteLLMClientError.unauthorized
        default:
            throw LiteLLMClientError.server(statusCode: httpResponse.statusCode)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --filter LiteLLMModelsTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/LiteLLMUsageBarCore/LiteLLMModels.swift Sources/LiteLLMUsageBarCore/LiteLLMClient.swift Tests/LiteLLMUsageBarCoreTests/LiteLLMModelsTests.swift
git commit -m "feat: decode litellm usage responses"
```

---

### Task 3: Usage Aggregation

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/UsageModels.swift`
- Create: `Sources/LiteLLMUsageBarCore/UsageAggregator.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/UsageAggregatorTests.swift`

- [ ] **Step 1: Write failing aggregation tests**

Create `Tests/LiteLLMUsageBarCoreTests/UsageAggregatorTests.swift`:

```swift
import XCTest
@testable import LiteLLMUsageBarCore

final class UsageAggregatorTests: XCTestCase {
    func testAggregatesMonthToDateAndTodaySpend() throws {
        let calendar = gregorianUTC()
        let today = ISO8601DateFormatter().date(from: "2026-06-03T10:30:00Z")!
        let rows = [
            DailyUsageRow(day: "2026-05-31", spend: Decimal(string: "9.99")!),
            DailyUsageRow(day: "2026-06-01", spend: Decimal(string: "2.00")!, requestCount: 1),
            DailyUsageRow(day: "2026-06-02", spend: Decimal(string: "3.50")!, requestCount: 2),
            DailyUsageRow(day: "2026-06-03", spend: Decimal(string: "4.25")!, requestCount: 3)
        ]

        let snapshot = try UsageAggregator(calendar: calendar).makeSnapshot(
            dailyActivity: DailyActivityResponse(rows: rows),
            userInfo: UserInfoResponse(
                userBudget: Decimal(20),
                keyBudget: Decimal(10),
                userSpend: Decimal(string: "42.10"),
                currency: "USD",
                budgetResetAt: ISO8601DateFormatter().date(from: "2026-07-01T00:00:00Z")
            ),
            now: today
        )

        XCTAssertEqual(snapshot.monthToDateSpend, Decimal(string: "9.75"))
        XCTAssertEqual(snapshot.todaySpend, Decimal(string: "4.25"))
        XCTAssertEqual(snapshot.budget?.limit, Decimal(20))
        XCTAssertEqual(snapshot.budget?.percentUsed, 0.4875, accuracy: 0.0001)
        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertEqual(snapshot.periodIdentifier, "2026-07-01T00:00:00Z")
    }

    func testBudgetUnavailableWhenNoBudgetReturned() throws {
        let calendar = gregorianUTC()
        let now = ISO8601DateFormatter().date(from: "2026-06-03T10:30:00Z")!

        let snapshot = try UsageAggregator(calendar: calendar).makeSnapshot(
            dailyActivity: DailyActivityResponse(rows: [
                DailyUsageRow(day: "2026-06-03", spend: Decimal(string: "4.25")!)
            ]),
            userInfo: UserInfoResponse(userBudget: nil, keyBudget: nil, userSpend: nil, currency: nil, budgetResetAt: nil),
            now: now
        )

        XCTAssertNil(snapshot.budget)
        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertEqual(snapshot.periodIdentifier, "2026-06")
    }

    private func gregorianUTC() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter UsageAggregatorTests
```

Expected: FAIL because `UsageSnapshot`, `BudgetSnapshot`, and `UsageAggregator` are not defined.

- [ ] **Step 3: Add usage domain models**

Create `Sources/LiteLLMUsageBarCore/UsageModels.swift`:

```swift
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
```

- [ ] **Step 4: Add aggregator**

Create `Sources/LiteLLMUsageBarCore/UsageAggregator.swift`:

```swift
import Combine
import Foundation

public struct UsageAggregator {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar.current) {
        self.calendar = calendar
    }

    public func makeSnapshot(
        dailyActivity: DailyActivityResponse,
        userInfo: UserInfoResponse,
        now: Date
    ) throws -> UsageSnapshot {
        let monthRows = dailyActivity.rows.filter { row in
            guard let date = Self.dayFormatter.date(from: row.day) else {
                return false
            }
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
                && calendar.isDate(date, equalTo: now, toGranularity: .year)
        }

        let todayKey = Self.dayFormatter.string(from: now)
        let monthToDateSpend = monthRows.reduce(Decimal.zero) { $0 + $1.spend }
        let todaySpend = monthRows.first(where: { $0.day == todayKey })?.spend ?? Decimal.zero
        let currency = userInfo.currency ?? "USD"
        let budgetLimit = userInfo.preferredBudget
        let budget = budgetLimit.map {
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

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

public func / (lhs: Decimal, rhs: Decimal) -> Decimal {
    var left = lhs
    var right = rhs
    var result = Decimal()
    NSDecimalDivide(&result, &left, &right, .bankers)
    return result
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --filter UsageAggregatorTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/LiteLLMUsageBarCore/UsageModels.swift Sources/LiteLLMUsageBarCore/UsageAggregator.swift Tests/LiteLLMUsageBarCoreTests/UsageAggregatorTests.swift
git commit -m "feat: aggregate litellm usage snapshots"
```

---

### Task 4: Display Formatting View Model

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/UsageViewModel.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/UsageViewModelTests.swift`

- [ ] **Step 1: Write failing display tests**

Create `Tests/LiteLLMUsageBarCoreTests/UsageViewModelTests.swift`:

```swift
import XCTest
@testable import LiteLLMUsageBarCore

final class UsageViewModelTests: XCTestCase {
    func testLoadedStateFormatsTitleAndMenuRows() {
        let snapshot = UsageSnapshot(
            monthToDateSpend: Decimal(string: "42.1")!,
            todaySpend: Decimal(string: "3.75")!,
            budget: BudgetSnapshot(limit: Decimal(100), spend: Decimal(string: "42.1")!, resetAt: nil),
            currency: "USD",
            lastUpdatedAt: ISO8601DateFormatter().date(from: "2026-06-03T12:30:00Z")!,
            periodIdentifier: "2026-06"
        )

        let display = UsageDisplayState.make(
            from: .loaded(snapshot),
            now: ISO8601DateFormatter().date(from: "2026-06-03T12:35:00Z")!
        )

        XCTAssertEqual(display.menuBarTitle, "$42.10 MTD")
        XCTAssertEqual(display.monthToDateText, "Month to date: $42.10")
        XCTAssertEqual(display.todayText, "Today: $3.75")
        XCTAssertEqual(display.budgetText, "Budget: $42.10 of $100.00 (42%)")
        XCTAssertEqual(display.lastUpdatedText, "Updated 5 min ago")
        XCTAssertNil(display.messageText)
    }

    func testMissingKeyAndUnavailableStates() {
        let now = ISO8601DateFormatter().date(from: "2026-06-03T12:35:00Z")!

        let missing = UsageDisplayState.make(from: .missingAPIKey(stale: nil), now: now)
        XCTAssertEqual(missing.menuBarTitle, "Set API Key")
        XCTAssertEqual(missing.messageText, "Enter a LiteLLM API key in Settings.")

        let unavailable = UsageDisplayState.make(from: .failed(error: .malformedResponse, stale: nil), now: now)
        XCTAssertEqual(unavailable.menuBarTitle, "Usage unavailable")
        XCTAssertEqual(unavailable.messageText, "Usage data format changed")
    }

    func testFailedStateKeepsStaleMenuBarSpend() {
        let stale = UsageSnapshot(
            monthToDateSpend: Decimal(string: "18.5")!,
            todaySpend: Decimal(string: "1.25")!,
            budget: nil,
            currency: "USD",
            lastUpdatedAt: ISO8601DateFormatter().date(from: "2026-06-03T12:00:00Z")!,
            periodIdentifier: "2026-06"
        )
        let now = ISO8601DateFormatter().date(from: "2026-06-03T12:35:00Z")!

        let display = UsageDisplayState.make(from: .failed(error: .networkOrServer, stale: stale), now: now)

        XCTAssertEqual(display.menuBarTitle, "$18.50 MTD")
        XCTAssertEqual(display.budgetText, "Budget unavailable")
        XCTAssertEqual(display.messageText, "Last refresh failed")
        XCTAssertEqual(display.lastUpdatedText, "Updated 35 min ago")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter UsageViewModelTests
```

Expected: FAIL because `UsageDisplayState` is not defined.

- [ ] **Step 3: Add display state formatter**

Create `Sources/LiteLLMUsageBarCore/UsageViewModel.swift`:

```swift
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
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter UsageViewModelTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LiteLLMUsageBarCore/UsageViewModel.swift Tests/LiteLLMUsageBarCoreTests/UsageViewModelTests.swift
git commit -m "feat: format usage display state"
```

---

### Task 5: Secure Keychain And Snapshot Storage

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/KeychainStore.swift`
- Create: `Sources/LiteLLMUsageBarCore/SnapshotStore.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/SnapshotStoreTests.swift`

- [ ] **Step 1: Write failing snapshot persistence tests**

Create `Tests/LiteLLMUsageBarCoreTests/SnapshotStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter SnapshotStoreTests
```

Expected: FAIL because `UserDefaultsSnapshotStore` is not defined.

- [ ] **Step 3: Add Keychain store protocol and implementation**

Create `Sources/LiteLLMUsageBarCore/KeychainStore.swift`:

```swift
import Foundation
import Security

public protocol APIKeyStore {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
    func clearAPIKey() throws
}

public enum KeychainStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidData
}

public final class KeychainAPIKeyStore: APIKeyStore {
    private let service: String
    private let account: String

    public init(
        service: String = AppConstants.keychainService,
        account: String = AppConstants.keychainAccount
    ) {
        self.service = service
        self.account = account
    }

    public func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard
            let data = result as? Data,
            let apiKey = String(data: data, encoding: .utf8)
        else {
            throw KeychainStoreError.invalidData
        }
        return apiKey
    }

    public func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }
        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(updateStatus)
            }
            return
        }
        throw KeychainStoreError.unexpectedStatus(addStatus)
    }

    public func clearAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
```

- [ ] **Step 4: Add snapshot persistence protocol and implementation**

Create `Sources/LiteLLMUsageBarCore/SnapshotStore.swift`:

```swift
import Foundation

public protocol SnapshotStore {
    func load() throws -> UsageSnapshot?
    func save(_ snapshot: UsageSnapshot) throws
    func clear() throws
}

public final class UserDefaultsSnapshotStore: SnapshotStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConstants.snapshotDefaultsKey
    ) {
        self.defaults = defaults
        self.key = key
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> UsageSnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(UsageSnapshot.self, from: data)
    }

    public func save(_ snapshot: UsageSnapshot) throws {
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: key)
    }

    public func clear() throws {
        defaults.removeObject(forKey: key)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --filter SnapshotStoreTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/LiteLLMUsageBarCore/KeychainStore.swift Sources/LiteLLMUsageBarCore/SnapshotStore.swift Tests/LiteLLMUsageBarCoreTests/SnapshotStoreTests.swift
git commit -m "feat: persist api key and usage snapshot"
```

---

### Task 6: Budget Notification Deduping

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/NotificationService.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/NotificationServiceTests.swift`

- [ ] **Step 1: Write failing threshold tests**

Create `Tests/LiteLLMUsageBarCoreTests/NotificationServiceTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter NotificationServiceTests
```

Expected: FAIL because notification protocols and services are not defined.

- [ ] **Step 3: Add notification service and test doubles**

Create `Sources/LiteLLMUsageBarCore/NotificationService.swift`:

```swift
import Foundation
import UserNotifications

public protocol BudgetNotificationEvaluating {
    func evaluate(_ snapshot: UsageSnapshot) async
}

public protocol UserNotificationCentering {
    func requestAuthorization() async -> Bool
    func authorizationDescription() async -> String
    func deliver(title: String, body: String) async
}

public protocol ThresholdStore {
    func sentThresholds(for periodIdentifier: String) -> Set<Double>
    func markSent(_ threshold: Double, periodIdentifier: String)
}

public final class BudgetNotificationService: BudgetNotificationEvaluating {
    private let thresholds: [Double]
    private let center: UserNotificationCentering
    private let thresholdStore: ThresholdStore

    public init(
        thresholds: [Double] = AppConstants.notificationThresholds,
        center: UserNotificationCentering,
        thresholdStore: ThresholdStore
    ) {
        self.thresholds = thresholds.sorted()
        self.center = center
        self.thresholdStore = thresholdStore
    }

    public func evaluate(_ snapshot: UsageSnapshot) async {
        guard let budget = snapshot.budget else {
            return
        }
        let alreadySent = thresholdStore.sentThresholds(for: snapshot.periodIdentifier)
        let crossed = thresholds.filter { budget.percentUsed >= $0 && !alreadySent.contains($0) }
        guard !crossed.isEmpty else {
            return
        }
        guard await center.requestAuthorization() else {
            return
        }

        for threshold in crossed {
            let percentage = Int(threshold * 100)
            await center.deliver(
                title: "LiteLLM budget \(percentage)% used",
                body: "Your LiteLLM spend is \(Int((budget.percentUsed * 100).rounded()))% of budget."
            )
            thresholdStore.markSent(threshold, periodIdentifier: snapshot.periodIdentifier)
        }
    }
}

public final class UserDefaultsThresholdStore: ThresholdStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = AppConstants.thresholdDefaultsKey) {
        self.defaults = defaults
        self.key = key
    }

    public func sentThresholds(for periodIdentifier: String) -> Set<Double> {
        let dictionary = defaults.dictionary(forKey: key) as? [String: [Double]] ?? [:]
        return Set(dictionary[periodIdentifier] ?? [])
    }

    public func markSent(_ threshold: Double, periodIdentifier: String) {
        var dictionary = defaults.dictionary(forKey: key) as? [String: [Double]] ?? [:]
        var values = Set(dictionary[periodIdentifier] ?? [])
        values.insert(threshold)
        dictionary[periodIdentifier] = Array(values).sorted()
        defaults.set(dictionary, forKey: key)
    }
}

public final class UNUserNotificationCenterAdapter: UserNotificationCentering {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    public func authorizationDescription() async -> String {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            return "Notifications enabled"
        case .denied:
            return "Notifications disabled"
        case .notDetermined:
            return "Notifications not requested"
        case .provisional:
            return "Notifications provisional"
        case .ephemeral:
            return "Notifications ephemeral"
        @unknown default:
            return "Notifications unknown"
        }
    }

    public func deliver(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }
}
```

Create `Tests/LiteLLMUsageBarCoreTests/NotificationServiceTestDoubles.swift`:

```swift
import Foundation
@testable import LiteLLMUsageBarCore

final class RecordingNotificationCenter: UserNotificationCentering {
    private(set) var deliveredTitles: [String] = []
    var authorizationAllowed = true

    func requestAuthorization() async -> Bool {
        authorizationAllowed
    }

    func authorizationDescription() async -> String {
        authorizationAllowed ? "Notifications enabled" : "Notifications disabled"
    }

    func deliver(title: String, body: String) async {
        deliveredTitles.append(title)
    }
}

final class InMemoryThresholdStore: ThresholdStore {
    private var values: [String: Set<Double>] = [:]

    func sentThresholds(for periodIdentifier: String) -> Set<Double> {
        values[periodIdentifier] ?? []
    }

    func markSent(_ threshold: Double, periodIdentifier: String) {
        var set = values[periodIdentifier] ?? []
        set.insert(threshold)
        values[periodIdentifier] = set
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
swift test --filter NotificationServiceTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/LiteLLMUsageBarCore/NotificationService.swift Tests/LiteLLMUsageBarCoreTests/NotificationServiceTests.swift Tests/LiteLLMUsageBarCoreTests/NotificationServiceTestDoubles.swift
git commit -m "feat: dedupe budget threshold notifications"
```

---

### Task 7: Refresh Coordination Service

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/UsageService.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/UsageServiceTests.swift`

- [ ] **Step 1: Write failing refresh tests**

Create `Tests/LiteLLMUsageBarCoreTests/UsageServiceTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --filter UsageServiceTests
```

Expected: FAIL because `UsageService` and its test doubles are not defined.

- [ ] **Step 3: Add UsageService**

Create `Sources/LiteLLMUsageBarCore/UsageService.swift`:

```swift
import Foundation

@MainActor
public final class UsageService: ObservableObject {
    public enum RefreshTrigger {
        case timer
        case manual
    }

    @Published public private(set) var state: UsageRefreshState

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

        let stale = state.latestSnapshot ?? (try? snapshotStore.load()) ?? nil
        guard let apiKey = try? apiKeyStore.loadAPIKey(), apiKey.isEmpty == false else {
            state = .missingAPIKey(stale: stale)
            return
        }

        state = .loading(stale: stale)
        let token = UUID()
        refreshToken = token
        let task = Task { [client, aggregator, dateProvider, snapshotStore, notificationService] in
            do {
                let now = dateProvider.now()
                let range = aggregator.currentMonthRange(containing: now)
                async let activity = client.fetchDailyActivity(apiKey: apiKey, startDate: range.start, endDate: range.end)
                async let userInfo = client.fetchUserInfo(apiKey: apiKey)
                let snapshot = try aggregator.makeSnapshot(
                    dailyActivity: try await activity,
                    userInfo: try await userInfo,
                    now: now
                )
                try? snapshotStore.save(snapshot)
                await notificationService.evaluate(snapshot)
                await MainActor.run {
                    self.state = .loaded(snapshot)
                }
            } catch {
                await MainActor.run {
                    self.state = .failed(error: Self.map(error), stale: stale)
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
```

- [ ] **Step 4: Add test doubles for refresh tests**

Create `Tests/LiteLLMUsageBarCoreTests/UsageServiceTestDoubles.swift`:

```swift
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

    init(apiKey: String?) {
        self.apiKey = apiKey
    }

    func loadAPIKey() throws -> String? {
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --filter UsageServiceTests
```

Expected: PASS.

- [ ] **Step 6: Run all core tests**

Run:

```bash
swift test
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/LiteLLMUsageBarCore/UsageService.swift Tests/LiteLLMUsageBarCoreTests/UsageServiceTests.swift Tests/LiteLLMUsageBarCoreTests/UsageServiceTestDoubles.swift
git commit -m "feat: coordinate usage refreshes"
```

---

### Task 8: Menu Bar App Shell

**Files:**
- Create: `Sources/LiteLLMUsageBar/main.swift`
- Create: `Sources/LiteLLMUsageBar/AppDelegate.swift`
- Create: `Sources/LiteLLMUsageBar/StatusBarController.swift`
- Create: `Sources/LiteLLMUsageBar/SettingsWindowController.swift`
- Create: `Sources/LiteLLMUsageBar/SettingsView.swift`

- [ ] **Step 1: Add app entry point**

Create `Sources/LiteLLMUsageBar/main.swift`:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Add app delegate and object graph**

Create `Sources/LiteLLMUsageBar/AppDelegate.swift`:

```swift
import AppKit
import LiteLLMUsageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var usageService: UsageService!
    private var statusBarController: StatusBarController!
    private var settingsWindowController: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notificationCenter = UNUserNotificationCenterAdapter()
        let notificationService = BudgetNotificationService(
            center: notificationCenter,
            thresholdStore: UserDefaultsThresholdStore()
        )
        let keyStore = KeychainAPIKeyStore()
        usageService = UsageService(
            client: URLSessionLiteLLMClient(),
            apiKeyStore: keyStore,
            snapshotStore: UserDefaultsSnapshotStore(),
            notificationService: notificationService
        )
        settingsWindowController = SettingsWindowController(
            apiKeyStore: keyStore,
            usageService: usageService,
            notificationCenter: notificationCenter
        )
        statusBarController = StatusBarController(
            usageService: usageService,
            openSettings: { [weak settingsWindowController] in
                settingsWindowController?.show()
            }
        )
        usageService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageService.stop()
    }
}
```

- [ ] **Step 3: Add status bar controller**

Create `Sources/LiteLLMUsageBar/StatusBarController.swift`:

```swift
import AppKit
import Combine
import LiteLLMUsageBarCore

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let usageService: UsageService
    private let openSettings: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    init(usageService: UsageService, openSettings: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.usageService = usageService
        self.openSettings = openSettings
        super.init()
        configureButton()
        bind()
    }

    private func configureButton() {
        statusItem.button?.title = "Usage..."
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showMenu)
    }

    private func bind() {
        usageService.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                let display = UsageDisplayState.make(from: state, now: Date())
                self?.statusItem.button?.title = display.menuBarTitle
            }
            .store(in: &cancellables)
    }

    @objc private func showMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let display = UsageDisplayState.make(from: usageService.state, now: Date())
        let menu = NSMenu()

        let header = NSMenuItem(title: display.headerText, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        menu.addItem(disabledItem(display.monthToDateText))
        menu.addItem(disabledItem(display.todayText))
        menu.addItem(disabledItem(display.budgetText))
        menu.addItem(disabledItem(display.lastUpdatedText))

        if let message = display.messageText {
            menu.addItem(.separator())
            menu.addItem(disabledItem(message))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r", target: self))
        menu.addItem(NSMenuItem(title: "Open LiteLLM UI", action: #selector(openLiteLLMUI), keyEquivalent: "o", target: self))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettingsWindow), keyEquivalent: ",", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q", target: self))
        return menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func refreshNow() {
        Task { await usageService.refresh(trigger: .manual) }
    }

    @objc private func openLiteLLMUI() {
        NSWorkspace.shared.open(AppConstants.liteLLMUIURL)
    }

    @objc private func openSettingsWindow() {
        openSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private extension NSMenuItem {
    convenience init(title: String, action: Selector?, keyEquivalent: String, target: AnyObject) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}
```

- [ ] **Step 4: Add settings window controller**

Create `Sources/LiteLLMUsageBar/SettingsWindowController.swift`:

```swift
import AppKit
import SwiftUI
import LiteLLMUsageBarCore

@MainActor
final class SettingsWindowController {
    private let apiKeyStore: APIKeyStore
    private let usageService: UsageService
    private let notificationCenter: UserNotificationCentering
    private var window: NSWindow?

    init(
        apiKeyStore: APIKeyStore,
        usageService: UsageService,
        notificationCenter: UserNotificationCentering
    ) {
        self.apiKeyStore = apiKeyStore
        self.usageService = usageService
        self.notificationCenter = notificationCenter
    }

    func show() {
        if window == nil {
            let view = SettingsView(
                viewModel: SettingsViewModel(
                    apiKeyStore: apiKeyStore,
                    usageService: usageService,
                    notificationCenter: notificationCenter
                )
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "LiteLLM UsageBar Settings"
            window.contentView = NSHostingView(rootView: view)
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 5: Add SwiftUI settings view**

Create `Sources/LiteLLMUsageBar/SettingsView.swift`:

```swift
import SwiftUI
import LiteLLMUsageBarCore

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var statusText: String = ""
    @Published var notificationStatus: String = "Checking notifications..."

    private let apiKeyStore: APIKeyStore
    private let usageService: UsageService
    private let notificationCenter: UserNotificationCentering

    init(
        apiKeyStore: APIKeyStore,
        usageService: UsageService,
        notificationCenter: UserNotificationCentering
    ) {
        self.apiKeyStore = apiKeyStore
        self.usageService = usageService
        self.notificationCenter = notificationCenter
        self.apiKey = (try? apiKeyStore.loadAPIKey()) ?? ""
        Task { await refreshNotificationStatus() }
    }

    func save() {
        do {
            try apiKeyStore.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            statusText = "API key saved"
            usageService.reloadAfterKeyChange()
        } catch {
            statusText = "Unable to save API key"
        }
    }

    func clear() {
        do {
            try apiKeyStore.clearAPIKey()
            apiKey = ""
            statusText = "API key cleared"
            usageService.reloadAfterKeyChange()
        } catch {
            statusText = "Unable to clear API key"
        }
    }

    func refreshNotificationStatus() async {
        notificationStatus = await notificationCenter.authorizationDescription()
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LiteLLM UsageBar")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("API key")
                    .font(.headline)
                SecureField("LiteLLM API key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save") { viewModel.save() }
                        .keyboardShortcut(.defaultAction)
                    Button("Clear") { viewModel.clear() }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Gateway")
                    .font(.headline)
                Text(AppConstants.gatewayURL.absoluteString)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications")
                    .font(.headline)
                Text(viewModel.notificationStatus)
                Button("Refresh Notification Status") {
                    Task { await viewModel.refreshNotificationStatus() }
                }
            }

            Text(viewModel.statusText)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(width: 460, height: 320)
    }
}
```

- [ ] **Step 6: Build the app**

Run:

```bash
swift build
```

Expected: PASS.

- [ ] **Step 7: Launch the app for manual smoke verification**

Run:

```bash
swift run LiteLLMUsageBar
```

Expected: A macOS menu bar item appears with `Set API Key` when no key is stored. Clicking it shows the summary-first menu with `Refresh Now`, `Open LiteLLM UI`, `Settings...`, and `Quit`. The app does not show a dock icon because activation policy is `.accessory`.

- [ ] **Step 8: Commit**

```bash
git add Sources/LiteLLMUsageBar/main.swift Sources/LiteLLMUsageBar/AppDelegate.swift Sources/LiteLLMUsageBar/StatusBarController.swift Sources/LiteLLMUsageBar/SettingsWindowController.swift Sources/LiteLLMUsageBar/SettingsView.swift
git commit -m "feat: add macos menu bar shell"
```

---

### Task 9: End-to-End Verification And Release Notes

**Files:**
- Create: `README.md`
- Create: `docs/manual-verification.md`

- [ ] **Step 1: Add user-facing README**

Create `README.md`:

```markdown
# LiteLLM UsageBar

Native macOS menu bar app for viewing current-user LiteLLM gateway spend from `https://llm-gateway.razorpay.com`.

## Features

- Month-to-date spend in the macOS menu bar
- Click menu with today's spend, budget progress, last updated time, and refresh actions
- Secure API key storage in macOS Keychain
- Automatic refresh every 5 minutes
- Manual refresh from the menu
- Budget notifications at 50%, 80%, and 100% when LiteLLM exposes a budget

## Build

```bash
swift build
```

## Test

```bash
swift test
```

## Run

```bash
swift run LiteLLMUsageBar
```

The app stores the LiteLLM key only in macOS Keychain. It uses this request header:

```text
x-litellm-api-key: Bearer <api-key>
```

The LiteLLM UI action opens:

```text
https://llm-gateway.razorpay.com/ui
```
```

- [ ] **Step 2: Add manual verification checklist**

Create `docs/manual-verification.md`:

```markdown
# Manual Verification

Run the app:

```bash
swift run LiteLLMUsageBar
```

## Checklist

- First launch with no stored key shows `Set API Key`.
- Click menu opens with `LiteLLM Usage`, spend rows, `Refresh Now`, `Open LiteLLM UI`, `Settings...`, and `Quit`.
- Settings opens from the menu and shows a secure API-key input.
- Saving an API key writes to Keychain and triggers refresh.
- Clearing an API key removes it from Keychain and returns the app to missing-key state.
- Invalid key returns `API key invalid or unauthorized` while preserving last successful spend if one exists.
- Network or server failure returns `Last refresh failed` while preserving last successful spend if one exists.
- Missing budget shows `Budget unavailable` and no threshold notification is sent.
- Budget at 50%, 80%, and 100% sends each notification once for the current period.
- Quitting from the menu terminates the process.
```

- [ ] **Step 3: Run full automated verification**

Run:

```bash
swift test
swift build
```

Expected: Both commands PASS.

- [ ] **Step 4: Run manual no-key smoke check**

Run:

```bash
swift run LiteLLMUsageBar
```

Expected: Menu bar title is `Set API Key`. Settings can be opened. Quit works.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/manual-verification.md
git commit -m "docs: add usagebar verification notes"
```

---

## Self-Review

- Spec coverage: The plan covers menu bar title states, summary-first click menu, settings, secure Keychain storage, five-minute refresh, manual refresh, in-memory and persisted snapshot cache, user/key budget precedence, missing-budget behavior, 401/403 handling, malformed response handling, threshold notifications, and no network calls in tests.
- Scope check: The app is one coherent subsystem. The core/app split keeps testable behavior independent from the macOS shell.
- Type consistency: The planned types are `DailyActivityResponse`, `UserInfoResponse`, `UsageSnapshot`, `BudgetSnapshot`, `UsageAggregator`, `UsageDisplayState`, `UsageService`, `APIKeyStore`, `SnapshotStore`, `BudgetNotificationService`, `StatusBarController`, and `SettingsViewModel`.
- Residual risk: The exact LiteLLM response shape may differ from the examples. The decoder accepts common envelope names and spend/budget field aliases, and malformed responses surface as `Usage data format changed` while preserving cached data.
