import XCTest
@testable import LiteLLMUsageBarCore

final class MenuBarAmountVisibilityStoreTests: XCTestCase {
    func testDefaultsToShowingAmount() {
        let defaults = UserDefaults(suiteName: "MenuBarAmountVisibilityStoreTests.defaults")!
        defaults.removePersistentDomain(forName: "MenuBarAmountVisibilityStoreTests.defaults")
        let store = UserDefaultsMenuBarAmountVisibilityStore(defaults: defaults)

        XCTAssertTrue(store.showsAmountOnMenuBar)
        XCTAssertEqual(store.toggleButtonTitle, "Hide Amount on Bar")
    }

    func testTogglePersistsHiddenState() {
        let defaults = UserDefaults(suiteName: "MenuBarAmountVisibilityStoreTests.toggle")!
        defaults.removePersistentDomain(forName: "MenuBarAmountVisibilityStoreTests.toggle")
        let store = UserDefaultsMenuBarAmountVisibilityStore(defaults: defaults)

        store.toggle()

        XCTAssertFalse(store.showsAmountOnMenuBar)
        XCTAssertEqual(store.toggleButtonTitle, "Show Amount on Bar")
        XCTAssertFalse(UserDefaultsMenuBarAmountVisibilityStore(defaults: defaults).showsAmountOnMenuBar)
    }
}
