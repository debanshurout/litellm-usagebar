import Foundation
import Security

public protocol APIKeyStore {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
    func clearAPIKey() throws
}

public enum KeychainStoreError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidData
}

public final class KeychainAPIKeyStore: APIKeyStore {
    private let service: String
    private let account: String
    private var cachedAPIKey: String?
    private var hasLoadedAPIKey = false

    public init(
        service: String = AppConstants.keychainService,
        account: String = AppConstants.keychainAccount
    ) {
        self.service = service
        self.account = account
    }

    public func loadAPIKey() throws -> String? {
        if hasLoadedAPIKey {
            return cachedAPIKey
        }

        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            hasLoadedAPIKey = true
            cachedAPIKey = nil
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard
            let data = result as? Data,
            let apiKey = String(data: data, encoding: .utf8)
        else {
            throw KeychainStoreError.invalidData
        }
        hasLoadedAPIKey = true
        cachedAPIKey = apiKey
        return apiKey
    }

    public func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus == errSecSuccess {
            hasLoadedAPIKey = true
            cachedAPIKey = apiKey
            return
        }
        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                baseQuery() as CFDictionary,
                [
                    kSecValueData as String: data,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
                ] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainStoreError.unexpectedStatus(updateStatus)
            }
            hasLoadedAPIKey = true
            cachedAPIKey = apiKey
            return
        }
        throw KeychainStoreError.unexpectedStatus(addStatus)
    }

    public func clearAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        hasLoadedAPIKey = true
        cachedAPIKey = nil
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
