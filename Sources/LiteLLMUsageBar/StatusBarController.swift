import AppKit
import Combine
import LiteLLMUsageBarCore

@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let usageService: UsageService
    private let amountVisibilityStore: MenuBarAmountVisibilityStore
    private let openSettings: () -> Void
    private var currentDisplay = UsageDisplayState.make(from: .loading(stale: nil), now: Date())
    private var cancellables: Set<AnyCancellable> = []

    init(
        usageService: UsageService,
        amountVisibilityStore: MenuBarAmountVisibilityStore,
        openSettings: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.usageService = usageService
        self.amountVisibilityStore = amountVisibilityStore
        self.openSettings = openSettings
        super.init()
        configureButton()
        bind()
    }

    private func configureButton() {
        statusItem.button?.title = "Usage..."
        statusItem.button?.target = self
        statusItem.button?.action = #selector(showMenu)
        renderStatusItem()
    }

    private func bind() {
        usageService.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                let display = UsageDisplayState.make(from: state, now: Date())
                self?.currentDisplay = display
                self?.renderStatusItem()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .menuBarAmountVisibilityDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.renderStatusItem()
            }
            .store(in: &cancellables)
    }

    private func renderStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        if amountVisibilityStore.showsAmountOnMenuBar {
            statusItem.length = NSStatusItem.variableLength
            button.title = currentDisplay.menuBarTitle
            button.image = nil
            button.imagePosition = .noImage
            return
        }

        statusItem.length = 28
        button.title = ""
        button.image = Self.dollarIcon()
        button.imagePosition = .imageOnly
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

private extension StatusBarController {
    static func dollarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor(calibratedRed: 0.12, green: 0.58, blue: 0.94, alpha: 1).set()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 22),
            .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.58, blue: 0.94, alpha: 1),
            .paragraphStyle: paragraphStyle
        ]
        NSString(string: "$").draw(
            in: NSRect(x: 0, y: -3, width: size.width, height: size.height + 4),
            withAttributes: attributes
        )

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

private extension NSMenuItem {
    convenience init(title: String, action: Selector?, keyEquivalent: String, target: AnyObject) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.target = target
    }
}
