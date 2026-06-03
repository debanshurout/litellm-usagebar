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

        menu.addItem(informationalItem(display.headerText, font: .boldSystemFont(ofSize: NSFont.systemFontSize)))
        menu.addItem(.separator())
        menu.addItem(informationalItem(display.monthToDateText))
        menu.addItem(informationalItem(display.todayText))
        menu.addItem(informationalItem(display.budgetText))
        menu.addItem(informationalItem(display.lastUpdatedText))

        if let message = display.messageText {
            menu.addItem(.separator())
            menu.addItem(informationalItem(message))
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r", target: self))
        menu.addItem(NSMenuItem(title: "Open LiteLLM UI", action: #selector(openLiteLLMUI), keyEquivalent: "o", target: self))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettingsWindow), keyEquivalent: ",", target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q", target: self))
        return menu
    }

    private func informationalItem(_ title: String, font: NSFont = .systemFont(ofSize: NSFont.systemFontSize)) -> NSMenuItem {
        let label = NSTextField(labelWithString: title)
        label.font = font
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 28))
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        let item = NSMenuItem()
        item.view = container
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
