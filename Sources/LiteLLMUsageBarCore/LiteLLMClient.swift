import Foundation

public protocol LiteLLMClient {
    func fetchDailyActivity(apiKey: String, startDate: Date, endDate: Date) async throws -> DailyActivityResponse
    func fetchUserInfo(apiKey: String) async throws -> UserInfoResponse
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

    private func get<T: Decodable>(_ url: URL, apiKey: String, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "x-litellm-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LiteLLMClientError.malformedResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw LiteLLMClientError.malformedResponse
            }
        case 401, 403:
            throw LiteLLMClientError.unauthorized
        default:
            throw LiteLLMClientError.server(statusCode: httpResponse.statusCode)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
