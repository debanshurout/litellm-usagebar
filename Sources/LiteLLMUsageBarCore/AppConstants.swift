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
