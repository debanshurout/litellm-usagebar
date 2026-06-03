import AppKit
import LiteLLMUsageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var usageService: UsageService!
    private var statusBarController: StatusBarController!
    private var settingsWindowController: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let notificationCenter: UserNotificationCentering
        if Bundle.main.bundleIdentifier == nil {
            notificationCenter = DisabledUserNotificationCenterAdapter(
                reason: "Notifications unavailable outside an app bundle"
            )
        } else {
            notificationCenter = UNUserNotificationCenterAdapter()
        }
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
