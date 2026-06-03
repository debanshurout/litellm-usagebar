# Menu Bar Amount Toggle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persisted settings option to show or hide the amount directly on the macOS menu bar.

**Architecture:** Add a core `MenuBarAmountVisibilityStore` backed by `UserDefaults`, inject it into settings and status bar controllers, and publish changes with `NotificationCenter` so status bar updates immediately. Generate the blue dollar status icon in AppKit code instead of adding image assets.

**Tech Stack:** SwiftPM, Swift, SwiftUI, AppKit, UserDefaults, NotificationCenter.

---

### Task 1: Preference Store

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/MenuBarAmountVisibilityStore.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/MenuBarAmountVisibilityStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run targeted test**

Run: `swift test --filter MenuBarAmountVisibilityStoreTests`

Expected: compile failure before implementation, or the known local `no such module 'XCTest'` toolchain failure.

- [ ] **Step 3: Implement store**

Create a public protocol with `showsAmountOnMenuBar`, `toggleButtonTitle`, and `toggle()`. Implement a `UserDefaultsMenuBarAmountVisibilityStore` that defaults to true by storing an inverted hide flag. Post `.menuBarAmountVisibilityDidChange` when toggled.

### Task 2: Status Bar Binding

**Files:**
- Modify: `Sources/LiteLLMUsageBar/StatusBarController.swift`
- Modify: `Sources/LiteLLMUsageBar/AppDelegate.swift`

- [ ] **Step 1: Inject store into `StatusBarController`**

Add `amountVisibilityStore: MenuBarAmountVisibilityStore` to the initializer and save it.

- [ ] **Step 2: Update status item rendering**

When `showsAmountOnMenuBar` is true, set `statusItem.button?.title` to the existing display title and clear `image`.

When false, set `title` to empty and set `image` to a generated blue dollar icon.

- [ ] **Step 3: Observe preference changes**

Listen for `.menuBarAmountVisibilityDidChange` and re-render the current usage state immediately.

### Task 3: Settings Button

**Files:**
- Modify: `Sources/LiteLLMUsageBar/SettingsWindowController.swift`
- Modify: `Sources/LiteLLMUsageBar/SettingsView.swift`
- Modify: `Sources/LiteLLMUsageBar/AppDelegate.swift`

- [ ] **Step 1: Inject store into settings**

Pass the same store instance from `AppDelegate` to `SettingsWindowController` and `SettingsViewModel`.

- [ ] **Step 2: Add view model state**

Expose `menuBarAmountButtonTitle`, initialized from the store.

- [ ] **Step 3: Add button action**

Call `amountVisibilityStore.toggle()` and refresh `menuBarAmountButtonTitle`.

- [ ] **Step 4: Render settings section**

Add a `Menu Bar` section with one button using the exact title from the view model.

### Task 4: Verify and Commit

**Files:**
- All changed files

- [ ] **Step 1: Build**

Run: `swift build`

Expected: build completes successfully.

- [ ] **Step 2: Relaunch app**

Stop the running `LiteLLMUsageBar` process and run `swift run LiteLLMUsageBar`.

Expected: app launches and refresh succeeds. The settings button toggles the status item between amount text and blue dollar icon.

- [ ] **Step 3: Commit**

```bash
git add Sources Tests docs
git commit -m "feat: toggle menu bar amount display"
```
