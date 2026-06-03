import AppKit
import LiteLLMUsageBarCore
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var keyEntryState: APIKeySettingsState
    @Published var statusText: String = ""
    @Published var notificationStatus: String = "Checking notifications..."

    private let apiKeyStore: APIKeyStore
    private let usageService: UsageService
    private let notificationCenter: UserNotificationCentering

    init(
        apiKeyStore: APIKeyStore,
        usageService: UsageService,
        notificationCenter: UserNotificationCentering
    ) {
        self.apiKeyStore = apiKeyStore
        self.usageService = usageService
        self.notificationCenter = notificationCenter
        let storedAPIKey = (try? apiKeyStore.loadAPIKey()) ?? ""
        self.apiKey = storedAPIKey
        self.keyEntryState = APIKeySettingsState(existingAPIKey: storedAPIKey)
        Task { await refreshNotificationStatus() }
    }

    func save() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAPIKey.isEmpty == false else {
            statusText = "API key is required"
            return
        }

        do {
            try apiKeyStore.saveAPIKey(trimmedAPIKey)
            apiKey = trimmedAPIKey
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

    func pasteAPIKeyFromClipboard() {
        guard let clipboardText = NSPasteboard.general.string(forType: .string) else {
            statusText = "Clipboard is empty"
            return
        }

        apiKey = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        statusText = "API key pasted"
    }

    func beginResave() {
        keyEntryState.beginResave()
        statusText = ""
    }

    func refreshNotificationStatus() async {
        notificationStatus = await notificationCenter.authorizationDescription()
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("LiteLLM UsageBar")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("API key")
                    .font(.headline)
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
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Gateway")
                    .font(.headline)
                Text(AppConstants.gatewayURL.absoluteString)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notifications")
                    .font(.headline)
                Text(viewModel.notificationStatus)
                Button("Refresh Notification Status") {
                    Task { await viewModel.refreshNotificationStatus() }
                }
            }

            Text(viewModel.statusText)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(width: 460, height: 320)
    }
}
