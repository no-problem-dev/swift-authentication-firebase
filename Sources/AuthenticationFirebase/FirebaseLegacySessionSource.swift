import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// The Firebase session an earlier version of the app left on the device, for
/// `SessionAuthenticator` to exchange at the session server's `/v1/auth/firebase`.
///
/// The server keeps the Firebase uid as the user id, so the person's records stay theirs. Once
/// the exchange succeeded the Firebase session is signed out, and so is it when the person
/// signs out of the new session — otherwise starting again would exchange it back.
///
/// `Auth` is resolved only when the authenticator asks, which is only on a device with no
/// session of its own yet. Configure Firebase inside the closure, so a device that already has
/// a session never starts Firebase. `FirebaseApp.configure()` traps when called twice, hence
/// the guard:
///
/// ```swift
/// SessionAuthenticator(
///     baseURL: apiURL,
///     installID: { InstallID.current },
///     legacySource: FirebaseLegacySessionSource {
///         if FirebaseApp.app() == nil {
///             FirebaseConfigurator.configure(sessionAfterReinstall: .keep)
///         }
///         return Auth.auth()
///     }
/// )
/// ```
public struct FirebaseLegacySessionSource: LegacySessionSource {
    private let auth: @Sendable () -> Auth

    /// Creates a source.
    ///
    /// - Parameter auth: Returns the Firebase instance whose signed-in user is the earlier
    ///   session. Called each time the authenticator asks, so it may configure Firebase first.
    ///   The shared instance by default, which requires Firebase to be configured already.
    public init(auth: @escaping @Sendable () -> Auth = { Auth.auth() }) {
        self.auth = auth
    }

    /// The signed-in Firebase user's ID token, or `nil` when there is no Firebase user.
    ///
    /// - Throws: Firebase's error when the token could not be obtained — no network, say.
    public func legacyIDToken() async throws -> String? {
        guard let user = auth().currentUser else { return nil }
        return try await user.getIDToken()
    }

    /// Signs out of Firebase, which removes its session from the keychain.
    public func discardLegacySession() async throws {
        try auth().signOut()
    }
}
