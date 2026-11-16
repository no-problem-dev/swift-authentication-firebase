import Foundation
import Authentication

/// The Firebase user an earlier version of the app left in the keychain, read without the
/// Firebase SDK, for `SessionAuthenticator` to exchange at the session server's
/// `/v1/auth/firebase`.
///
/// Firebase Authentication keeps its signed-in user as a keyed archive of `FIRUser` in a
/// generic-password item. This reads the item, takes out the refresh token, and hands it over as
/// ``LegacyCredential/firebaseRefreshToken(_:)``; the server trades it at Google for an ID token
/// and keeps the Firebase uid as the user id. The device never talks to Google, so the move works
/// where Google cannot be reached.
///
/// ```swift
/// SessionAuthenticator(
///     baseURL: apiURL,
///     installID: { InstallID.current },
///     // GOOGLE_APP_ID from the GoogleService-Info.plist the earlier version shipped.
///     legacySource: FirebaseKeychainLegacySessionSource(googleAppID: "1:1234567890:ios:abcdef")
/// )
/// ```
///
/// Read without a request, ``storedUser()`` also tells who the earlier version had signed in —
/// for a screen that shows the person as signed in while the exchange waits for the network.
public struct FirebaseKeychainLegacySessionSource: LegacySessionSource {
    /// The Firebase app name the SDK uses unless the app configured another.
    public static let defaultAppName = "__FIRAPP_DEFAULT"

    private let item: FirebaseUserKeychainItem
    private let keychain: any KeychainItems

    /// Creates a source.
    ///
    /// - Parameters:
    ///   - googleAppID: `GOOGLE_APP_ID` from the app's `GoogleService-Info.plist`. Firebase files
    ///     its keychain item under the service `firebase_auth_<googleAppID>`.
    ///   - appName: The Firebase app's name. Only an app that configured a named `FirebaseApp`
    ///     passes another.
    public init(googleAppID: String, appName: String = Self.defaultAppName) {
        self.init(item: FirebaseUserKeychainItem(googleAppID: googleAppID, appName: appName), keychain: SystemKeychain())
    }

    init(item: FirebaseUserKeychainItem, keychain: any KeychainItems) {
        self.item = item
        self.keychain = keychain
    }

    /// The Firebase user in the keychain, or `nil` when there is none.
    ///
    /// - Throws: ``FirebaseKeychainError``. A keychain that could not be read, and an item that
    ///   is not a Firebase user this version understands, are not the same as no user — the
    ///   person's records may be under it — so they are reported, never treated as `nil`.
    public func storedUser() throws -> FirebaseKeychainUser? {
        guard let data = try item.read(from: keychain) else { return nil }
        return try FirebaseUserArchive.decode(data, key: item.userKey)
    }

    /// The stored user's refresh token, or `nil` when there is no Firebase user.
    ///
    /// - Throws: ``FirebaseKeychainError``, as for ``storedUser()``.
    public func legacyCredential() async throws -> LegacyCredential? {
        try storedUser().map { .firebaseRefreshToken($0.refreshToken) }
    }

    /// Removes the Firebase user from the keychain — the item the SDK writes today, and the one
    /// the oldest versions wrote. Succeeds when there was none.
    ///
    /// - Throws: ``FirebaseKeychainError/keychainFailed(status:)``.
    public func discard() async throws {
        try item.remove(from: keychain)
    }
}

/// Who the earlier version of the app had signed in to Firebase, as its keychain item says.
public struct FirebaseKeychainUser: Sendable, Equatable {
    /// The Firebase uid. The session server keeps it as the user id.
    public let uid: String
    /// The refresh token that the server trades at Google for an ID token.
    public let refreshToken: String
    /// Whether Firebase had the user as anonymous.
    public let isAnonymous: Bool
    public let email: String?
    public let displayName: String?
    /// Firebase's identifiers of the linked providers, such as `apple.com` and `google.com`.
    public let firebaseProviderIDs: [String]

    public init(
        uid: String,
        refreshToken: String,
        isAnonymous: Bool,
        email: String?,
        displayName: String?,
        firebaseProviderIDs: [String]
    ) {
        self.uid = uid
        self.refreshToken = refreshToken
        self.isAnonymous = isAnonymous
        self.email = email
        self.displayName = displayName
        self.firebaseProviderIDs = firebaseProviderIDs
    }

    /// The user as `Authentication` describes one: `apple.com` and `google.com` become
    /// `.apple` and `.google`; providers the session server does not know are left out.
    public var authUser: AuthUser {
        AuthUser(
            id: uid,
            email: email,
            displayName: displayName,
            isAnonymous: isAnonymous,
            providerIDs: firebaseProviderIDs.compactMap { id in
                switch id {
                case "apple.com": .apple
                case "google.com": .google
                default: nil
                }
            }
        )
    }
}

/// Why the Firebase user in the keychain could not be read.
public enum FirebaseKeychainError: Error, Equatable, Sendable {
    /// A keychain call returned this status — `errSecInteractionNotAllowed` when the app runs
    /// in the background before the device was first unlocked, say. May pass; try again later.
    case keychainFailed(status: OSStatus)
    /// The item is not a keyed archive. `reason` is what the unarchiver said.
    case notAKeyedArchive(reason: String)
    /// The item is a keyed archive but not the `FIRUser` this version reads: no user under the
    /// expected key, no uid, no refresh token, or classes it does not know. `reason` says which.
    case unexpectedArchive(reason: String)
}
