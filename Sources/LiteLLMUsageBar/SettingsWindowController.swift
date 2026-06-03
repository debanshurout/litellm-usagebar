import AppKit
import LiteLLMUsageBarCore
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let apiKeyStore: APIKeyStore
    private let usageService: UsageService
    private let connectionTester: LiteLLMClient
    private let notificationCenter: UserNotificationCentering
    private var window: NSWindow?

    init(
        apiKeyStore: APIKeyStore,
        usageService: UsageService,
        connectionTester: LiteLLMClient,
        notificationCenter: UserNotificationCentering
    ) {
        self.apiKeyStore = apiKeyStore
        self.usageService = usageService
        self.connectionTester = connectionTester
        self.notificationCenter = notificationCenter
    }

    func show() {
        if window == nil {
            let view = SettingsView(
                viewModel: SettingsViewModel(
                    apiKeyStore: apiKeyStore,
                    usageService: usageService,
                    connectionTester: connectionTester,
                    notificationCenter: notificationCenter
                )
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 350),
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
