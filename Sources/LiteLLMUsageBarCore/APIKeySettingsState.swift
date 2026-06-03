import Foundation

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
        let saved = existingAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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
