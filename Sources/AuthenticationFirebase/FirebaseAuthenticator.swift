import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Exchanges credentials for a session using Firebase Authentication.
///
/// For apps that have not moved to `SessionAuthenticator` yet. New apps do not use it.
///
/// Converts the neutral `AuthCredential` into Firebase's own credential type and trades it
/// for a session. Firebase stores that session in the keychain, which outlives the process and
/// even the app's deletion — see `FirebaseConfigurator` for why that matters on reinstall.
public final class FirebaseAuthenticator: Authenticator, Sendable {
    private let backend: any FirebaseAuthBackend
    private let accountDeletion: (any AccountDeletion)?
    private let renewals = RenewedCredentials()

    /// Creates an authenticator.
    ///
    /// - Parameters:
    ///   - auth: The Firebase authentication instance to use. Defaults to the shared one; pass
    ///     another only to substitute it in tests.
    ///   - accountDeletion: Where ``deleteAccount(appleAuthorizationCode:)`` deletes the account. `nil`, the default,
    ///     deletes the Firebase account from the device, which Firebase refuses when the last
    ///     sign-in is too old and which leaves the app's own server data alone. An app with a
    ///     server passes a conformance that calls its deletion endpoint, so the server deletes
    ///     the data and the account in one request.
    public convenience init(auth: Auth = Auth.auth(), accountDeletion: (any AccountDeletion)? = nil) {
        self.init(backend: LiveFirebaseAuthBackend(auth: auth), accountDeletion: accountDeletion)
    }

    init(backend: any FirebaseAuthBackend, accountDeletion: (any AccountDeletion)? = nil) {
        self.backend = backend
        self.accountDeletion = accountDeletion
    }

    /// Returns the user restored from the keychain-backed session, or `nil` when there is
    /// none. Reads local state only — no network call, no token refresh.
    public func currentUser() async -> AuthUser? {
        backend.currentUser()
    }

    /// Trades a credential for a Firebase session and returns the user it belongs to.
    ///
    /// An anonymous credential carries no tokens, so it opens an anonymous session instead of
    /// being exchanged. Any other credential replaces the current session — an anonymous one
    /// included, whose user id and data are then left behind. Use ``link(with:)`` to keep them.
    ///
    /// - Parameter credential: What the acquisition layer produced.
    /// - Returns: The signed-in user.
    /// - Throws: `AuthError.accountExistsWithDifferentProvider` when the credential's email
    ///   address belongs to an account that uses another provider. Otherwise Firebase's
    ///   authentication error, or ``FirebaseAuthenticatorError`` when the credential is missing
    ///   the fields its provider requires.
    public func signIn(with credential: Authentication.AuthCredential) async throws -> AuthUser {
        if let firebaseCredential = try FirebaseCredentialMapper.makeCredential(from: credential) {
            return try await exchange(firebaseCredential, provider: credential.provider)
        }
        return try await backend.signInAnonymously()
    }

    /// Links a credential to the signed-in Firebase user, keeping its uid.
    ///
    /// - Parameter credential: An Apple or Google credential.
    /// - Returns: The same user, now linked to the credential's provider.
    /// - Throws: `AuthError.notAuthenticated` when nobody is signed in.
    ///   `AuthError.credentialAlreadyInUse` when another Firebase account already owns the
    ///   credential; its payload carries the replacement credential Firebase issued, which
    ///   ``signIn(resolving:)`` uses. `AuthError.accountExistsWithDifferentProvider` when the
    ///   credential's email address belongs to an account that uses another provider
    ///   (Firebase's `emailAlreadyInUse` and `accountExistsWithDifferentCredential`).
    ///   `AuthError.linkFailed` for everything else, including a
    ///   credential that cannot be converted and a provider already linked to this user.
    public func link(with credential: Authentication.AuthCredential) async throws -> AuthUser {
        let firebaseCredential: FirebaseAuth.AuthCredential
        do {
            guard let converted = try FirebaseCredentialMapper.makeCredential(from: credential) else {
                throw FirebaseAuthenticatorError.invalidCredential(credential.provider)
            }
            firebaseCredential = converted
        } catch {
            throw AuthError.linkFailed(error)
        }

        let linked: AuthUser?
        do {
            linked = try await backend.linkCurrentUser(with: firebaseCredential)
        } catch let error as NSError
            where error.domain == AuthErrors.domain
            && error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            if let renewed = error.userInfo[AuthErrors.userInfoUpdatedCredentialKey] as? FirebaseAuth.AuthCredential {
                renewals.keep(renewed, for: credential)
            }
            throw AuthError.credentialAlreadyInUse(
                CredentialCollision(credential: credential, email: error.userInfo[AuthErrors.userInfoEmailKey] as? String)
            )
        } catch let error as NSError where Self.isOtherProvidersEmail(error) {
            throw Self.otherProvidersEmail(error, provider: credential.provider)
        } catch {
            throw AuthError.linkFailed(error)
        }
        guard let linked else { throw AuthError.notAuthenticated }
        return linked
    }

    /// Removes a provider from the signed-in Firebase user, keeping its uid.
    ///
    /// Firebase keeps `isAnonymous` false afterwards; ``AuthUser/providerIDs`` tells whether
    /// anything is still linked.
    ///
    /// - Throws: `AuthError.notAuthenticated` when nobody is signed in, and Firebase's error —
    ///   `noSuchProvider` when the provider was not linked.
    public func unlink(_ provider: Authentication.AuthProviderID) async throws -> AuthUser {
        guard let user = try await backend.unlinkCurrentUser(fromProvider: FirebaseUserMapper.firebaseProviderID(provider)) else {
            throw AuthError.notAuthenticated
        }
        return user
    }

    /// Signs in to the Firebase account a credential already belongs to, or returns `nil`.
    ///
    /// Firebase cannot ask whether an account exists without creating one, so this links the
    /// credential to the signed-in user: a collision means an account owns it, and this signs
    /// in to that account through ``signIn(resolving:)``; a successful link means none did,
    /// and the provider is unlinked again.
    ///
    /// - Throws: `AuthError.notAuthenticated` when nobody is signed in; otherwise as for
    ///   ``link(with:)`` and ``signIn(resolving:)``.
    public func signInExisting(with credential: Authentication.AuthCredential) async throws -> AuthUser? {
        do {
            _ = try await link(with: credential)
        } catch let AuthError.credentialAlreadyInUse(collision) {
            return try await signIn(resolving: collision)
        }
        _ = try await unlink(credential.provider)
        return nil
    }

    /// Signs in to the Firebase account that owns a credential which failed to link.
    ///
    /// Uses the replacement credential Firebase issued with the rejection. Without one, a
    /// Google credential is exchanged again, which Firebase accepts; an Apple one is not,
    /// because Firebase has already consumed the nonce inside its identity token and a second
    /// exchange fails with "Duplicate credential received".
    ///
    /// - Parameter collision: The payload of the `AuthError.credentialAlreadyInUse` that
    ///   ``link(with:)`` threw.
    /// - Returns: The user of the owning account. The uid changes to that account's.
    /// - Throws: `AuthError.credentialAlreadyInUse(collision)` unchanged when Firebase issued no
    ///   replacement for an Apple credential — a fresh credential from the provider is needed —
    ///   `AuthError.accountExistsWithDifferentProvider` as for ``signIn(with:)``, and Firebase's
    ///   error when the exchange fails.
    public func signIn(resolving collision: CredentialCollision) async throws -> AuthUser {
        if let renewed = renewals.take(for: collision.credential) {
            return try await exchange(renewed, provider: collision.provider)
        }
        guard collision.provider == .google,
              let reusable = try FirebaseCredentialMapper.makeCredential(from: collision.credential) else {
            throw AuthError.credentialAlreadyInUse(collision)
        }
        return try await exchange(reusable, provider: collision.provider)
    }

    /// Clears the keychain-backed session.
    ///
    /// Identity tokens already issued remain valid until they expire, so a backend that needs
    /// immediate lockout has to revoke them itself.
    ///
    /// - Throws: Firebase's sign-out error.
    public func signOut() async throws {
        try backend.signOut()
    }

    /// Deletes the account, then ends the local session. Irreversible.
    ///
    /// With an Apple authorization code, the person's Sign in with Apple tokens are revoked
    /// first (App Review guideline 5.1.1(v)) — before the deletion, because Firebase authorizes
    /// the revocation with the current user's ID token.
    ///
    /// With an `accountDeletion` given at init, that does the deleting — normally the app's
    /// server, removing its data and the Firebase account in one request — and the session is
    /// cleared only after it succeeds, so a failed request can be retried with the same bearer
    /// token. Without one, the Firebase account is deleted from the device.
    ///
    /// - Throws: `AuthError.notAuthenticated` when no one is signed in; Firebase's error when
    ///   the revocation fails, with nothing deleted; whatever the
    ///   `accountDeletion` threw, with the session untouched; on the device path, Firebase's
    ///   refusal when the last sign-in is too old (`requiresRecentLogin`), thrown as-is.
    ///   `AuthError.signOutFailed` when the account is gone but the local session could not be
    ///   cleared.
    public func deleteAccount(appleAuthorizationCode: String?) async throws {
        guard let user = backend.currentUser() else {
            throw AuthError.notAuthenticated
        }
        if let appleAuthorizationCode {
            try await backend.revokeToken(authorizationCode: appleAuthorizationCode)
        }
        if let accountDeletion {
            try await accountDeletion.deleteAccount(of: user, appleAuthorizationCode: appleAuthorizationCode)
        } else {
            try await backend.deleteCurrentUser()
        }
        do {
            try backend.signOut()
        } catch {
            throw AuthError.signOutFailed(error)
        }
    }

    /// A stream of the signed-in user, emitting `nil` while signed out.
    ///
    /// The current value arrives as soon as the stream is iterated, which is Firebase's
    /// listener behaviour and what `AuthenticationStore` relies on to leave its checking
    /// state. The listener is removed when iteration ends.
    public func authStateChanges() -> AsyncStream<AuthUser?> {
        backend.stateChanges()
    }

    // MARK: - Internals

    private func exchange(_ credential: FirebaseAuth.AuthCredential, provider: Authentication.AuthProviderID) async throws -> AuthUser {
        do {
            return try await backend.signIn(with: credential)
        } catch let error as NSError where Self.isOtherProvidersEmail(error) {
            throw Self.otherProvidersEmail(error, provider: provider)
        }
    }

    private static let otherProvidersEmailCodes: Set<Int> = [
        AuthErrorCode.emailAlreadyInUse.rawValue,
        AuthErrorCode.accountExistsWithDifferentCredential.rawValue
    ]

    private static func isOtherProvidersEmail(_ error: NSError) -> Bool {
        error.domain == AuthErrors.domain && otherProvidersEmailCodes.contains(error.code)
    }

    private static func otherProvidersEmail(_ error: NSError, provider: Authentication.AuthProviderID) -> AuthError {
        .accountExistsWithDifferentProvider(provider: provider, email: error.userInfo[AuthErrors.userInfoEmailKey] as? String)
    }
}

/// The replacement credentials Firebase issued with `credentialAlreadyInUse`, kept until
/// ``FirebaseAuthenticator/signIn(resolving:)`` uses them, keyed by the credential that collided.
///
/// `@unchecked` because Firebase's credential classes are not marked `Sendable`; each one is
/// immutable once Firebase hands it over, and the lock guards the dictionary.
private final class RenewedCredentials: @unchecked Sendable {
    private let lock = NSLock()
    private var byCollidedToken: [String: FirebaseAuth.AuthCredential] = [:]

    func keep(_ renewed: FirebaseAuth.AuthCredential, for collided: Authentication.AuthCredential) {
        guard let key = collided.idToken else { return }
        lock.withLock { byCollidedToken[key] = renewed }
    }

    func take(for collided: Authentication.AuthCredential) -> FirebaseAuth.AuthCredential? {
        guard let key = collided.idToken else { return nil }
        return lock.withLock { byCollidedToken.removeValue(forKey: key) }
    }
}
