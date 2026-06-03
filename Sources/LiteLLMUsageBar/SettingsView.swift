import LiteLLMUsageBarCore
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var keyEntryState: APIKeySettingsState
    @Published var statusText: String = ""
    @Published var connectionStatusText: String = ""
    @Published var connectionStatusColor: Color = .secondary
    @Published var isTestingConnection = false
    @Published var notificationStatus: String = "Checking notifications..."

    private let apiKeyStore: APIKeyStore
    private let usageService: UsageService
    private let connectionTester: LiteLLMClient
    private let notificationCenter: UserNotificationCentering

    init(
        apiKeyStore: APIKeyStore,
        usageService: UsageService,
        connectionTester: LiteLLMClient,
        notificationCenter: UserNotificationCentering
    ) {
        self.apiKeyStore = apiKeyStore
        self.usageService = usageService
        self.connectionTester = connectionTester
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
            clearConnectionStatus()
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
            clearConnectionStatus()
            statusText = "API key cleared"
            usageService.reloadAfterKeyChange()
        } catch {
            statusText = "Unable to clear API key"
        }
    }

    func beginResave() {
        keyEntryState.beginResave()
        clearConnectionStatus()
        statusText = ""
    }

    func testConnection() {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAPIKey.isEmpty == false else {
            connectionStatusText = "Enter an API key to test"
            connectionStatusColor = .red
            return
        }

        isTestingConnection = true
        connectionStatusText = "Testing connection..."
        connectionStatusColor = .secondary

        Task {
            let result = await connectionTester.testConnection(apiKey: trimmedAPIKey)
            connectionStatusText = result.message(shouldPromptToSave: keyEntryState.shouldShowEditor)
            connectionStatusColor = result.isSuccess ? .green : .red
            isTestingConnection = false
        }
    }

    func refreshNotificationStatus() async {
        notificationStatus = await notificationCenter.authorizationDescription()
    }

    private func clearConnectionStatus() {
        connectionStatusText = ""
        connectionStatusColor = .secondary
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
                        .frame(width: Self.contentWidth)
                    HStack {
                        testConnectionButton
                        Button("Save") { viewModel.save() }
                            .keyboardShortcut(.defaultAction)
                    }
                } else {
                    Text(viewModel.keyEntryState.savedMessage)
                        .foregroundStyle(.secondary)
                    HStack {
                        testConnectionButton
                        Button("Resave Key") { viewModel.beginResave() }
                    }
                }

                if viewModel.connectionStatusText.isEmpty == false {
                    Text(viewModel.connectionStatusText)
                        .font(.callout)
                        .foregroundStyle(viewModel.connectionStatusColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: Self.contentWidth, alignment: .leading)
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
        .frame(width: Self.contentWidth, alignment: .leading)
        .padding(24)
        .frame(width: 460, height: 350, alignment: .top)
    }

    private var testConnectionButton: some View {
        Button("Test Connection") { viewModel.testConnection() }
            .disabled(viewModel.isTestingConnection)
    }

    private static let contentWidth: CGFloat = 240
}
