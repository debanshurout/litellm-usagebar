import AppKit
import LiteLLMUsageBarCore
import SwiftUI

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
