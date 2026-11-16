import Foundation
import Security

/// Where Firebase Authentication files its signed-in user in the keychain.
///
/// From firebase-ios-sdk `FirebaseAuth/Sources/Swift` (12.x; the Objective-C SDK used the same
/// names):
/// - `Auth.keychainServiceName(for:)`: service `firebase_auth_<GOOGLE_APP_ID>`
/// - `Auth.getUser()` / `saveUser(_:)`: key `<app name>_firebase_user`, `kUserKey = "_firebase_user"`
/// - `AuthKeychainServices.genericPasswordQuery(key:)`: generic password, account
///   `firebase_auth_1_<key>` under that service, in the data protection keychain
/// - `AuthKeychainServices.legacyGenericPasswordQuery(key:)`: what the oldest versions wrote —
///   account `<key>` with no service. The SDK still reads it when the first is missing.
///
/// Firebase's `useUserAccessGroup(_:)` keeps the user elsewhere (`AuthStoredUserManager`); this
/// does not read that.
struct FirebaseUserKeychainItem: Sendable, Equatable {
    let service: String
    /// The key the user is archived under, and the account suffix.
    let userKey: String

    init(googleAppID: String, appName: String) {
        service = "firebase_auth_\(googleAppID)"
        userKey = "\(appName)_firebase_user"
    }

    var account: String { "firebase_auth_1_\(userKey)" }

    /// The item's data: the current item first, then the one the oldest versions wrote.
    func read(from keychain: any KeychainItems) throws -> Data? {
        if let data = try keychain.data(service: service, account: account) { return data }
        return try keychain.data(service: nil, account: userKey)
    }

    func remove(from keychain: any KeychainItems) throws {
        try keychain.delete(service: service, account: account)
        try keychain.delete(service: nil, account: userKey)
    }
}

/// Generic-password items, so tests can stand in for the keychain.
protocol KeychainItems: Sendable {
    /// The item's data, or `nil` when there is no such item.
    func data(service: String?, account: String) throws -> Data?
    /// Removes the item. Succeeds when there is none.
    func delete(service: String?, account: String) throws
}

/// The device's keychain.
struct SystemKeychain: KeychainItems {
    func data(service: String?, account: String) throws -> Data? {
        var query = Self.query(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw FirebaseKeychainError.unexpectedArchive(reason: "the keychain item holds no data")
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw FirebaseKeychainError.keychainFailed(status: status)
        }
    }

    func delete(service: String?, account: String) throws {
        let status = SecItemDelete(Self.query(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw FirebaseKeychainError.keychainFailed(status: status)
        }
    }

    /// The SDK's queries: with a service it also asks for the data protection keychain (which
    /// matters on macOS only); the legacy query has neither.
    private static func query(service: String?, account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        if let service {
            query[kSecAttrService as String] = service
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }
}
