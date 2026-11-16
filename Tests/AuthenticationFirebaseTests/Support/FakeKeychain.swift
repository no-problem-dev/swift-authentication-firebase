import Foundation
import Security
@testable import AuthenticationFirebase

/// Generic-password items in memory. `nil` service is the SDK's legacy query: it matches any
/// service, as the keychain does.
final class FakeKeychain: KeychainItems, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [Key: Data] = [:]
    private var failure: OSStatus?

    struct Key: Hashable {
        let service: String?
        let account: String
    }

    func put(_ data: Data, service: String?, account: String) {
        lock.withLock { items[Key(service: service, account: account)] = data }
    }

    func fail(with status: OSStatus?) {
        lock.withLock { failure = status }
    }

    var keys: Set<Key> { lock.withLock { Set(items.keys) } }

    func data(service: String?, account: String) throws -> Data? {
        try lock.withLock {
            if let failure { throw FirebaseKeychainError.keychainFailed(status: failure) }
            return items.first { matches($0.key, service: service, account: account) }?.value
        }
    }

    func delete(service: String?, account: String) throws {
        try lock.withLock {
            if let failure { throw FirebaseKeychainError.keychainFailed(status: failure) }
            items = items.filter { !matches($0.key, service: service, account: account) }
        }
    }

    private func matches(_ key: Key, service: String?, account: String) -> Bool {
        key.account == account && (service == nil || key.service == service)
    }
}
