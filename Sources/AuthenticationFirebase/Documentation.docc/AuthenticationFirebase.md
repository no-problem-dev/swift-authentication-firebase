# ``AuthenticationFirebase``

Firebase Authentication, for apps moving to `SessionAuthenticator`. New apps do not use it.

## Overview

``FirebaseLegacySessionSource`` is what a moving app needs: handed to `SessionAuthenticator`,
it gives the session server the Firebase user's ID token once, and the person keeps their uid.
The rest of this module is the Firebase `Authenticator` an app keeps until it has moved.

`AuthenticationFirebase` implements the `Authenticator` protocol on top of Firebase: it
converts a vendor-agnostic `AuthCredential` into Firebase's own credential
type and trades it for a session. It also supplies identity tokens through
`AuthTokenProviding` and configures Firebase at launch.

Only Firebase Authentication is pulled in — no Firestore, no Storage — so application data
stays behind your own API.

Call ``FirebaseConfigurator/configure(environment:enableDebugMode:)`` once at launch. During
development, `.emulator` points the app at the Firebase Local Emulator Suite; release builds
refuse it outright, because authenticating real users against an emulator would mean trusting
anyone who can reach it.

```swift
import AuthenticationFirebase

// Once, from the app's initializer or the app delegate.
FirebaseConfigurator.configure(environment: .production)

// During development, debug builds only.
// FirebaseConfigurator.configure(environment: .emulator(host: "localhost", port: 9099))
```

By default, configuring also signs out on the first launch after an install. Firebase keeps
sessions in the keychain, which survives deleting the app, so without that step a reinstall
would silently restore whoever was signed in before. An app that signs in only anonymously wants
the opposite — signing out would strand the anonymous uid and everything the server keeps under
it — and passes ``FirebaseConfigurator/SessionAfterReinstall/keep`` to
``FirebaseConfigurator/configure(environment:sessionAfterReinstall:enableDebugMode:)``:

```swift
FirebaseConfigurator.configure(sessionAfterReinstall: .keep)
```

``FirebaseAuthenticator`` and ``FirebaseTokenProvider`` are injected into
`AuthenticationStore` at the composition root.

```swift
import Authentication
import AuthenticationFirebase

let authenticator = FirebaseAuthenticator()       // Uses the shared Auth instance.
let tokenProvider = FirebaseTokenProvider()

let store = AuthenticationStore(authenticator: authenticator)
```

``FirebaseConfigurator/googleClientID`` reads the client ID out of `GoogleService-Info.plist`,
so the composition root can hand it to `GoogleCredentialProvider` without importing
FirebaseCore itself.

### Linking and collisions

``FirebaseAuthenticator/link(with:)`` attaches an Apple or Google credential to the signed-in
user and keeps its uid, which is how an anonymous account is upgraded. When another account
already owns the credential it throws `AuthError.credentialAlreadyInUse`, and keeps the
replacement credential Firebase issued with it; ``FirebaseAuthenticator/signIn(resolving:)``
signs in with that replacement rather than with the credential that collided, whose Apple nonce
is already spent. ``FirebaseCredentialMapper`` is public for code that calls Firebase directly.

### Deleting the account

Pass an `AccountDeletion` to ``FirebaseAuthenticator/init(auth:accountDeletion:)`` and
``FirebaseAuthenticator/deleteAccount(appleAuthorizationCode:)`` calls it, then clears the local
session only after it succeeded. Without one, the Firebase account is deleted from the device,
which Firebase refuses when the last sign-in is too old. An Apple authorization code — which
`AuthenticationStore.deleteAccount()` obtains for an Apple-linked account — revokes the person's
Apple tokens first (App Review guideline 5.1.1(v)).

## Topics

### Moving to sessions

- ``FirebaseLegacySessionSource``

### Start-up

- ``FirebaseConfigurator``
- ``FirebaseConfigurator/Environment``
- ``FirebaseConfigurator/SessionAfterReinstall``

### Session exchange

- ``FirebaseAuthenticator``
- ``FirebaseAuthenticator/link(with:)``
- ``FirebaseAuthenticator/signIn(resolving:)``
- ``FirebaseCredentialMapper``
- ``FirebaseAuthenticatorError``

### Tokens

- ``FirebaseTokenProvider``
