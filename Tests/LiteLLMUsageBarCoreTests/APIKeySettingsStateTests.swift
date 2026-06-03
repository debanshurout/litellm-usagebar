import XCTest
@testable import LiteLLMUsageBarCore

final class APIKeySettingsStateTests: XCTestCase {
    func testExistingKeyStartsInSavedMode() {
        let state = APIKeySettingsState(existingAPIKey: "abc123")

        XCTAssertTrue(state.hasSavedKey)
        XCTAssertFalse(state.isEditing)
        XCTAssertFalse(state.shouldShowEditor)
        XCTAssertEqual(state.savedMessage, "LiteLLM token saved")
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
