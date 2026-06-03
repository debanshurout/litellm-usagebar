import Foundation

public extension Notification.Name {
    static let menuBarAmountVisibilityDidChange = Notification.Name("menuBarAmountVisibilityDidChange")
}

public protocol MenuBarAmountVisibilityStore: AnyObject {
    var showsAmountOnMenuBar: Bool { get }
    var toggleButtonTitle: String { get }
    func toggle()
}

public final class UserDefaultsMenuBarAmountVisibilityStore: MenuBarAmountVisibilityStore {
    private let defaults: UserDefaults
    private let hidesAmountKey = "menuBarHidesAmount"

    public var showsAmountOnMenuBar: Bool {
        defaults.bool(forKey: hidesAmountKey) == false
    }

    public var toggleButtonTitle: String {
        showsAmountOnMenuBar ? "Hide Amount on Bar" : "Show Amount on Bar"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func toggle() {
        defaults.set(showsAmountOnMenuBar, forKey: hidesAmountKey)
        NotificationCenter.default.post(name: .menuBarAmountVisibilityDidChange, object: self)
    }
}
