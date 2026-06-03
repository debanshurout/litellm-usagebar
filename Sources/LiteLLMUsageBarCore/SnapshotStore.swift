import Foundation

public protocol SnapshotStore {
    func load() throws -> UsageSnapshot?
    func save(_ snapshot: UsageSnapshot) throws
    func clear() throws
}

public final class UserDefaultsSnapshotStore: SnapshotStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        key: String = AppConstants.snapshotDefaultsKey
    ) {
        self.defaults = defaults
        self.key = key
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func load() throws -> UsageSnapshot? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(UsageSnapshot.self, from: data)
    }

    public func save(_ snapshot: UsageSnapshot) throws {
        let data = try encoder.encode(snapshot)
        defaults.set(data, forKey: key)
    }

    public func clear() throws {
        defaults.removeObject(forKey: key)
    }
}
