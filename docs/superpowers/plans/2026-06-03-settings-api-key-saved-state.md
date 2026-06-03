# Settings API Key Saved State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide the API key input after a key is saved, show a saved confirmation, and expose a Resave Key action that returns to edit mode.

**Architecture:** Add a small core state model for the saved/editing API key entry flow, then bind the existing SwiftUI settings view to that model. Keep Keychain persistence and usage refresh behavior unchanged.

**Tech Stack:** SwiftPM, Swift, SwiftUI, AppKit, XCTest-style unit tests where available.

---

### Task 1: Settings Key Entry State

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/APIKeySettingsState.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/APIKeySettingsStateTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import LiteLLMUsageBarCore

final class APIKeySettingsStateTests: XCTestCase {
    func testExistingKeyStartsInSavedMode() {
        let state = APIKeySettingsState(existingAPIKey: "abc123")

        XCTAssertTrue(state.hasSavedKey)
        XCTAssertFalse(state.isEditing)
        XCTAssertFalse(state.shouldShowEditor)
        XCTAssertEqual(state.savedMessage, "API key saved")
    }

    func testResaveSwitchesExistingKeyToEditMode() {
        var state = APIKeySettingsState(existingAPIKey: "abc123")

        state.beginResave()

        XCTAssertTrue(state.hasSavedKey)
        XCTAssertTrue(state.isEditing)
        XCTAssertTrue(state.shouldShowEditor)
    }

    func testSaveSwitchesBackToSavedMode() {
        var state = APIKeySettingsState(existingAPIKey: nil)

        state.markSaved()

        XCTAssertTrue(state.hasSavedKey)
        XCTAssertFalse(state.isEditing)
        XCTAssertFalse(state.shouldShowEditor)
    }

    func testClearReturnsToEditingMode() {
        var state = APIKeySettingsState(existingAPIKey: "abc123")

        state.markCleared()

        XCTAssertFalse(state.hasSavedKey)
        XCTAssertTrue(state.isEditing)
        XCTAssertTrue(state.shouldShowEditor)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter APIKeySettingsStateTests`

Expected: either a compile failure because `APIKeySettingsState` does not exist yet, or the local known `XCTest` toolchain failure if XCTest is unavailable.

- [ ] **Step 3: Write minimal implementation**

```swift
public struct APIKeySettingsState: Equatable {
    public private(set) var hasSavedKey: Bool
    public private(set) var isEditing: Bool

    public var shouldShowEditor: Bool {
        isEditing || !hasSavedKey
    }

    public var savedMessage: String {
        "API key saved"
    }

    public init(existingAPIKey: String?) {
        let saved = existingAPIKey?.isEmpty == false
        self.hasSavedKey = saved
        self.isEditing = !saved
    }

    public mutating func beginResave() {
        isEditing = true
    }

    public mutating func markSaved() {
        hasSavedKey = true
        isEditing = false
    }

    public mutating func markCleared() {
        hasSavedKey = false
        isEditing = true
    }
}
```

- [ ] **Step 4: Run verification**

Run: `swift build`

Expected: Build completes successfully. If `swift test` remains blocked by missing XCTest, report that explicitly.

### Task 2: Settings UI Binding

**Files:**
- Modify: `Sources/LiteLLMUsageBar/SettingsView.swift`

- [ ] **Step 1: Wire state into the view model**

```swift
@Published var keyEntryState: APIKeySettingsState

init(...) {
    let storedAPIKey = (try? apiKeyStore.loadAPIKey()) ?? ""
    self.apiKey = storedAPIKey
    self.keyEntryState = APIKeySettingsState(existingAPIKey: storedAPIKey)
    Task { await refreshNotificationStatus() }
}
```

- [ ] **Step 2: Update actions**

```swift
func save() {
    do {
        try apiKeyStore.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        keyEntryState.markSaved()
        statusText = ""
        usageService.reloadAfterKeyChange()
    } catch {
        statusText = "Unable to save API key"
    }
}

func clear() {
    do {
        try apiKeyStore.clearAPIKey()
        apiKey = ""
        keyEntryState.markCleared()
        statusText = "API key cleared"
        usageService.reloadAfterKeyChange()
    } catch {
        statusText = "Unable to clear API key"
    }
}

func beginResave() {
    keyEntryState.beginResave()
    statusText = ""
}
```

- [ ] **Step 3: Update SwiftUI conditional rendering**

```swift
if viewModel.keyEntryState.shouldShowEditor {
    SecureField("LiteLLM API key", text: $viewModel.apiKey)
        .textFieldStyle(.roundedBorder)
    HStack {
        Button("Save") { viewModel.save() }
            .keyboardShortcut(.defaultAction)
        Button("Paste") { viewModel.pasteAPIKeyFromClipboard() }
        Button("Clear") { viewModel.clear() }
    }
} else {
    Text(viewModel.keyEntryState.savedMessage)
        .foregroundStyle(.secondary)
    Button("Resave Key") { viewModel.beginResave() }
}
```

- [ ] **Step 4: Build and relaunch**

Run: `swift build`

Run: `swift run LiteLLMUsageBar`

Expected: app launches, refresh succeeds, settings starts in saved mode when a key exists, and Resave Key returns to the previous edit controls.
