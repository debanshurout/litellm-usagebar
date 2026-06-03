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

public final class DisabledUserNotificationCenterAdapter: UserNotificationCentering {
    private let reason: String

    public init(reason: String = "Notifications unavailable") {
        self.reason = reason
    }

    public func requestAuthorization() async -> Bool {
        false
    }

    public func authorizationDescription() async -> String {
        reason
    }

    public func deliver(title: String, body: String) async {}
}
