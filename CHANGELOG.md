# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.0.0] - 2026-11-16

The package no longer depends on the Firebase SDK. It reads what Firebase Authentication left in
the keychain itself, and the session server trades the refresh token at Google.

### Added

- `FirebaseKeychainLegacySessionSource(googleAppID:appName:)`: reads the keyed archive of `FIRUser`
  from the keychain (service `firebase_auth_<GOOGLE_APP_ID>`, account
  `firebase_auth_1_<app name>_firebase_user`, and the oldest SDKs' unprefixed account) and returns
  `LegacyCredential.firebaseRefreshToken`. `discard()` removes both items. `storedUser()` returns
  the uid, email, display name and providers without a request.
- `FirebaseKeychainUser`, `FirebaseKeychainError` (`keychainFailed(status:)`, `notAKeyedArchive`,
  `unexpectedArchive`).

### Removed

- **Breaking:** the Firebase SDK dependency, and with it `FirebaseLegacySessionSource`,
  `FirebaseAuthenticator`, `FirebaseTokenProvider`, `FirebaseConfigurator` and the privacy
  manifest. Apps that still sign in through Firebase stay on 1.x.

### Changed

- Requires swift-authentication 12.0.0 (`LegacySessionSource` returns a `LegacyCredential`).

## [1.0.0] - 2026-11-16

### Added

- `FirebaseLegacySessionSource: LegacySessionSource`, which gives `SessionAuthenticator` the
  Firebase user's ID token to exchange once, and signs out of Firebase afterwards.

### Changed

- `AuthenticationFirebase` moved here from swift-authentication 10.x, adapted to 11.0.0:
  - `FirebaseAuthenticator.deleteAccount(appleAuthorizationCode:)` revokes the Apple tokens
    first when given a code, replacing `revokeAppleToken(authorizationCode:)`.
  - A collision carries the credential that collided; the replacement Firebase issued is kept
    inside the authenticator for `signIn(resolving:)`. Without one, a Google credential is
    exchanged again and an Apple one asks for a fresh credential.
  - `unlink(_:)`, and `signInExisting(with:)`, which links and unlinks again when the
    credential turns out to belong to nobody — Firebase cannot tell without creating.
  - Provider IDs are mapped to `.apple` and `.google` from Firebase's `apple.com` and
    `google.com`.
