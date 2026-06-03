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
        usageService.statePublisher
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
