import Foundation

public enum DiagnosticLogger {
    public static func log(_ message: String) {
        guard let data = "[LiteLLMUsageBar] \(message)\n".data(using: .utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }
}
