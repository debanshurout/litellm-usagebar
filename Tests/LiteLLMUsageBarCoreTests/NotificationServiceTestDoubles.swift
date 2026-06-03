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
