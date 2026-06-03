public struct ConnectionTestResult: Equatable {
    public let statusCode: Int?

    public var isSuccess: Bool {
        guard let statusCode else {
            return false
        }
        return (200..<300).contains(statusCode)
    }

    public var message: String {
        guard let statusCode else {
            return "Connection failed (no HTTP status)"
        }

        if isSuccess {
            return "Connection successful (HTTP \(statusCode))"
        }

        return "Connection failed (HTTP \(statusCode))"
    }

    public func message(shouldPromptToSave: Bool) -> String {
        guard isSuccess && shouldPromptToSave else {
            return message
        }

        return "\(message)\nClick Save to store this key."
    }

    public init(statusCode: Int?) {
        self.statusCode = statusCode
    }
}
