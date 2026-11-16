import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// The calls `FirebaseAuthenticator` makes into Firebase, and nothing else.
///
/// The seam exists so the authenticator's own decisions — which call a credential routes to,
/// how a collision is translated, what runs when an account is deleted and in which order —
/// can be tested without a network or an emulator. Each method is a direct call through to
/// Firebase in ``LiveFirebaseAuthBackend``; nothing here decides anything.
protocol FirebaseAuthBackend: Sendable {
    func currentUser() -> AuthUser?
    func signIn(with credential: FirebaseAuth.AuthCredential) async throws -> AuthUser
    func signInAnonymously() async throws -> AuthUser
    /// - Returns: `nil` when nobody is signed in.
    func linkCurrentUser(with credential: FirebaseAuth.AuthCredential) async throws -> AuthUser?
    /// - Returns: `nil` when nobody is signed in.
    func unlinkCurrentUser(fromProvider providerID: String) async throws -> AuthUser?
    /// Deletes the signed-in user's authentication account from the device.
    func deleteCurrentUser() async throws
    func signOut() throws
    func revokeToken(authorizationCode: String) async throws
    func stateChanges() -> AsyncStream<AuthUser?>
}

/// ``FirebaseAuthBackend`` over a real `Auth` instance.
struct LiveFirebaseAuthBackend: FirebaseAuthBackend, @unchecked Sendable {
    let auth: Auth

    func currentUser() -> AuthUser? {
        auth.currentUser.map(FirebaseUserMapper.map)
    }

    func signIn(with credential: FirebaseAuth.AuthCredential) async throws -> AuthUser {
        FirebaseUserMapper.map(try await auth.signIn(with: credential).user)
    }

    func signInAnonymously() async throws -> AuthUser {
        FirebaseUserMapper.map(try await auth.signInAnonymously().user)
    }

    func linkCurrentUser(with credential: FirebaseAuth.AuthCredential) async throws -> AuthUser? {
        guard let user = auth.currentUser else { return nil }
        return FirebaseUserMapper.map(try await user.link(with: credential).user)
    }

    func unlinkCurrentUser(fromProvider providerID: String) async throws -> AuthUser? {
        guard let user = auth.currentUser else { return nil }
        return FirebaseUserMapper.map(try await user.unlink(fromProvider: providerID))
    }

    func deleteCurrentUser() async throws {
        guard let user = auth.currentUser else { throw AuthError.notAuthenticated }
        try await user.delete()
    }

    func signOut() throws {
        try auth.signOut()
    }

    func revokeToken(authorizationCode: String) async throws {
        try await auth.revokeToken(withAuthorizationCode: authorizationCode)
    }

    func stateChanges() -> AsyncStream<AuthUser?> {
        // The listener belongs to the instance it was added to, which is not necessarily the
        // shared one — reaching for `Auth.auth()` here traps outright when no default app exists.
        nonisolated(unsafe) let auth = self.auth
        return AsyncStream { continuation in
            nonisolated(unsafe) let handle = auth.addStateDidChangeListener { _, user in
                continuation.yield(user.map(FirebaseUserMapper.map))
            }
            continuation.onTermination = { _ in
                auth.removeStateDidChangeListener(handle)
            }
        }
    }
}
