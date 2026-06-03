import Foundation

public protocol LiteLLMClient {
    func fetchDailyActivity(apiKey: String, startDate: Date, endDate: Date) async throws -> DailyActivityResponse
    func fetchUserInfo(apiKey: String) async throws -> UserInfoResponse
    func testConnection(apiKey: String) async -> ConnectionTestResult
}

public enum LiteLLMClientError: Error, Equatable {
    case unauthorized
    case server(statusCode: Int)
    case malformedResponse
}

public final class URLSessionLiteLLMClient: LiteLLMClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = AppConstants.gatewayURL,
        session: URLSession = .shared,
        decoder: JSONDecoder = .liteLLM
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    public func fetchDailyActivity(apiKey: String, startDate: Date, endDate: Date) async throws -> DailyActivityResponse {
        let url = baseURL
            .appendingPathComponent("user")
            .appendingPathComponent("daily")
            .appendingPathComponent("activity")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: Self.dayFormatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: Self.dayFormatter.string(from: endDate))
        ]
        return try await get(components.url!, apiKey: apiKey, as: DailyActivityResponse.self)
    }

    public func fetchUserInfo(apiKey: String) async throws -> UserInfoResponse {
        let url = baseURL
            .appendingPathComponent("user")
            .appendingPathComponent("info")
        return try await get(url, apiKey: apiKey, as: UserInfoResponse.self)
    }

    public func testConnection(apiKey: String) async -> ConnectionTestResult {
        let url = baseURL
            .appendingPathComponent("user")
            .appendingPathComponent("info")
        let request = makeGETRequest(url: url, apiKey: apiKey)

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                DiagnosticLogger.log("connection test failed: malformed HTTP response")
                return ConnectionTestResult(statusCode: nil)
            }

            DiagnosticLogger.log("connection test status=\(httpResponse.statusCode)")
            return ConnectionTestResult(statusCode: httpResponse.statusCode)
        } catch {
            DiagnosticLogger.log("connection test failed: \(error)")
            return ConnectionTestResult(statusCode: nil)
        }
    }

    private func get<T: Decodable>(_ url: URL, apiKey: String, as type: T.Type) async throws -> T {
        let request = makeGETRequest(url: url, apiKey: apiKey)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            DiagnosticLogger.log("GET \(url.path) failed: malformed HTTP response")
            throw LiteLLMClientError.malformedResponse
        }

        DiagnosticLogger.log("GET \(url.path) status=\(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                DiagnosticLogger.log("GET \(url.path) decode failed: \(error)")
                logResponseShape(data: data, path: url.path)
                throw LiteLLMClientError.malformedResponse
            }
        case 401, 403:
            throw LiteLLMClientError.unauthorized
        default:
            throw LiteLLMClientError.server(statusCode: httpResponse.statusCode)
        }
    }

    private func makeGETRequest(url: URL, apiKey: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-litellm-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func logResponseShape(data: Data, path: String) {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            DiagnosticLogger.log("GET \(path) response shape: non-json body")
            return
        }

        if let dictionary = object as? [String: Any] {
            DiagnosticLogger.log("GET \(path) response top-level keys=\(dictionary.keys.sorted())")
            for key in ["results", "data", "daily_activity", "activity"] {
                if let rows = dictionary[key] as? [[String: Any]], let firstRow = rows.first {
                    DiagnosticLogger.log("GET \(path) response \(key)[0] keys=\(firstRow.keys.sorted())")
                    logNestedKeys(firstRow, path: path, prefix: "\(key)[0]")
                    return
                }
            }
            return
        }

        if let rows = object as? [[String: Any]], let firstRow = rows.first {
            DiagnosticLogger.log("GET \(path) response array[0] keys=\(firstRow.keys.sorted())")
            logNestedKeys(firstRow, path: path, prefix: "array[0]")
        }
    }

    private func logNestedKeys(_ dictionary: [String: Any], path: String, prefix: String) {
        for (key, value) in dictionary.sorted(by: { $0.key < $1.key }) {
            if let nested = value as? [String: Any] {
                DiagnosticLogger.log("GET \(path) response \(prefix).\(key) keys=\(nested.keys.sorted())")
            }
        }
    }
}
