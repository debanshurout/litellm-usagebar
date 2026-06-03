import AppKit
import LiteLLMUsageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var usageService: UsageService!
    private var statusBarController: StatusBarController!
    private var settingsWindowController: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()

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
        let liteLLMClient = URLSessionLiteLLMClient()
        let amountVisibilityStore = UserDefaultsMenuBarAmountVisibilityStore()

        usageService = UsageService(
            client: liteLLMClient,
            apiKeyStore: keyStore,
            snapshotStore: UserDefaultsSnapshotStore(),
            notificationService: notificationService
        )
        settingsWindowController = SettingsWindowController(
            apiKeyStore: keyStore,
            usageService: usageService,
            connectionTester: liteLLMClient,
            notificationCenter: notificationCenter
        )
        statusBarController = StatusBarController(
            usageService: usageService,
            amountVisibilityStore: amountVisibilityStore,
            openSettings: { [weak settingsWindowController] in
                settingsWindowController?.show()
            }
        )
        usageService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageService.stop()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(
                title: "Quit LiteLLM UsageBar",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
