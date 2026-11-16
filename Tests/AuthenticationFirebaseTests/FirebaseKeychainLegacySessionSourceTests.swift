import Testing
import Foundation
import Security
import Authentication
@testable import AuthenticationFirebase

@Suite("FirebaseKeychainLegacySessionSource")
struct FirebaseKeychainLegacySessionSourceTests {
    private let item = FirebaseUserKeychainItem(googleAppID: "1:1234567890:ios:abcdef", appName: "__FIRAPP_DEFAULT")

    private func source(
        _ keychain: FakeKeychain,
        item: FirebaseUserKeychainItem? = nil,
        protectedData: FakeProtectedData = FakeProtectedData(available: true)
    ) -> FirebaseKeychainLegacySessionSource {
        FirebaseKeychainLegacySessionSource(item: item ?? self.item, keychain: keychain, protectedData: protectedData)
    }

    private func keychain(holding data: Data) -> FakeKeychain {
        let keychain = FakeKeychain()
        keychain.put(data, service: item.service, account: item.account)
        return keychain
    }

    // MARK: - Where the item is

    @Test("the item is where the SDK files it")
    func itemNames() {
        #expect(item.service == "firebase_auth_1:1234567890:ios:abcdef")
        #expect(item.account == "firebase_auth_1___FIRAPP_DEFAULT_firebase_user")
        #expect(item.userKey == "__FIRAPP_DEFAULT_firebase_user")
        let named = FirebaseUserKeychainItem(googleAppID: "1:2:ios:3", appName: "secondary")
        #expect(named.account == "firebase_auth_1_secondary_firebase_user")
    }

    // MARK: - Reading

    @Test("reads the uid, the refresh token and the profile of a signed-in user")
    func readsUser() async throws {
        let source = source(keychain(holding: FirebaseArchiveFixture.userArchive(
            providers: [
                .init(providerID: "google.com", uid: "google-sub", email: "person@example.com", displayName: "Person"),
                .init(providerID: "apple.com", uid: "apple-sub", email: nil, displayName: nil)
            ],
            withEnrolledFactor: true
        )))

        let user = try #require(try source.storedUser())

        #expect(user == FirebaseKeychainUser(
            uid: "firebase-uid-1",
            refreshToken: "AMf-refresh-token",
            isAnonymous: false,
            email: "person@example.com",
            displayName: "Person",
            firebaseProviderIDs: ["apple.com", "google.com"]
        ))
        #expect(user.authUser == AuthUser(id: "firebase-uid-1", email: "person@example.com", displayName: "Person", providerIDs: [.apple, .google]))
        #expect(try await source.legacyCredential() == .firebaseRefreshToken("AMf-refresh-token"))
    }

    @Test("reads an anonymous user with no providers")
    func readsAnonymousUser() throws {
        let source = source(keychain(holding: FirebaseArchiveFixture.userArchive(
            uid: "anon-uid", isAnonymous: true, email: nil, displayName: nil, providers: []
        )))

        let user = try #require(try source.storedUser())

        #expect(user.uid == "anon-uid")
        #expect(user.isAnonymous)
        #expect(user.firebaseProviderIDs.isEmpty)
        #expect(user.authUser.isAnonymous)
    }

    @Test("reads an archive written without secure coding, as older SDKs did")
    func readsInsecureArchive() throws {
        let source = source(keychain(holding: FirebaseArchiveFixture.userArchive(requiringSecureCoding: false)))
        #expect(try source.storedUser()?.refreshToken == "AMf-refresh-token")
    }

    @Test("falls back to the item the oldest SDKs wrote, with no service and no prefix")
    func readsLegacyItem() throws {
        let keychain = FakeKeychain()
        keychain.put(FirebaseArchiveFixture.userArchive(uid: "old-uid"), service: nil, account: item.userKey)
        #expect(try source(keychain).storedUser()?.uid == "old-uid")
    }

    @Test("prefers the current item to the legacy one")
    func prefersCurrentItem() throws {
        let keychain = keychain(holding: FirebaseArchiveFixture.userArchive(uid: "current-uid"))
        keychain.put(FirebaseArchiveFixture.userArchive(uid: "old-uid"), service: nil, account: item.userKey)
        #expect(try source(keychain).storedUser()?.uid == "current-uid")
    }

    @Test("an item of another Firebase app is not read")
    func otherAppIsNotRead() async throws {
        let keychain = FakeKeychain()
        keychain.put(FirebaseArchiveFixture.userArchive(), service: "firebase_auth_1:999:ios:other", account: item.account)
        #expect(try source(keychain).storedUser() == nil)
        #expect(try await source(keychain).legacyCredential() == nil)
    }

    @Test("no item is no user")
    func noItem() async throws {
        #expect(try source(FakeKeychain()).storedUser() == nil)
        #expect(try await source(FakeKeychain()).legacyCredential() == nil)
    }

    // MARK: - Failures are reported, not read as "no user"

    @Test("a keychain that cannot be read is reported with its status")
    func keychainFailure() async {
        let keychain = FakeKeychain()
        keychain.fail(with: errSecMissingEntitlement)
        #expect(throws: FirebaseKeychainError.keychainFailed(status: errSecMissingEntitlement)) {
            _ = try source(keychain).storedUser()
        }
        await #expect(throws: FirebaseKeychainError.keychainFailed(status: errSecMissingEntitlement)) {
            try await source(keychain).discard()
        }
    }

    // MARK: - Protected data not available

    @Test("a locked keychain is reported as protected data unavailable, not as no user")
    func lockedKeychain() async {
        let keychain = FakeKeychain()
        keychain.fail(with: errSecInteractionNotAllowed)
        #expect(throws: ProtectedDataUnavailable(status: errSecInteractionNotAllowed)) {
            _ = try source(keychain).storedUser()
        }
        await #expect(throws: ProtectedDataUnavailable(status: errSecInteractionNotAllowed)) {
            _ = try await source(keychain).legacyCredential()
        }
    }

    @Test("no item while protected data is unavailable is not no user, and is read once it is available")
    func notFoundWhileLocked() async throws {
        let keychain = FakeKeychain()
        let protectedData = FakeProtectedData(available: false)
        let source = source(keychain, protectedData: protectedData)

        #expect(throws: ProtectedDataUnavailable(status: errSecItemNotFound)) { _ = try source.storedUser() }
        await #expect(throws: ProtectedDataUnavailable(status: errSecItemNotFound)) {
            _ = try await source.legacyCredential()
        }

        protectedData.set(available: true)
        #expect(try source.storedUser() == nil)
    }

    @Test("an item that was read is used without asking about protected data")
    func readItemIsTrusted() async throws {
        let protectedData = FakeProtectedData(available: false)
        let source = source(keychain(holding: FirebaseArchiveFixture.userArchive()), protectedData: protectedData)

        #expect(try await source.legacyCredential() == .firebaseRefreshToken("AMf-refresh-token"))
        #expect(protectedData.askCount == 0)
    }

    @Test("bytes that are not a keyed archive")
    func notAnArchive() {
        let source = source(keychain(holding: Data("not an archive".utf8)))
        #expect { _ = try source.storedUser() } throws: {
            if case .notAKeyedArchive = $0 as? FirebaseKeychainError { return true }
            return false
        }
    }

    @Test("a keyed archive that is not the FIRUser this version reads", arguments: [
        ("archived under another key", FirebaseArchiveFixture.userArchive(key: "other_firebase_user"), "no FIRUser"),
        ("a class this version does not know", FirebaseArchiveFixture.userArchive(userClassName: "FIRUserV2"), ""),
        ("no uid", FirebaseArchiveFixture.userArchive(uid: nil), "no userID"),
        ("no token service", FirebaseArchiveFixture.userArchive(withTokenService: false), "no tokenService"),
        ("no refresh token", FirebaseArchiveFixture.userArchive(refreshToken: nil), "no refreshToken")
    ])
    func unexpectedArchive(_ name: String, _ data: Data, _ expectedReason: String) {
        let source = source(keychain(holding: data))
        #expect(name.isEmpty == false)
        #expect { _ = try source.storedUser() } throws: { error in
            guard case .unexpectedArchive(let reason) = error as? FirebaseKeychainError else { return false }
            return expectedReason.isEmpty || reason.contains(expectedReason)
        }
    }

    // MARK: - Discarding

    @Test("discarding removes the current and the legacy item, and the user is gone")
    func discardRemovesBoth() async throws {
        let keychain = keychain(holding: FirebaseArchiveFixture.userArchive())
        keychain.put(FirebaseArchiveFixture.userArchive(), service: nil, account: item.userKey)
        keychain.put(Data("unrelated".utf8), service: "AuthenticationSession", account: "session")
        let source = source(keychain)

        try await source.discard()

        #expect(try source.storedUser() == nil)
        #expect(keychain.keys == [FakeKeychain.Key(service: "AuthenticationSession", account: "session")])
    }

    @Test("discarding with nothing stored succeeds")
    func discardNothing() async throws {
        try await source(FakeKeychain()).discard()
    }
}
