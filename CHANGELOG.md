# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.1.0] - 2026-11-16

A launch the person did not start — prewarming, a background task — before the first unlock or
while the device is locked no longer reads the Firebase user as missing.

### Fixed

- `storedUser()` and `legacyCredential()` no longer answer `nil` while the device's protected
  data is unavailable. A locked keychain can return `errSecItemNotFound` for the item that is
  there (firebase-ios-sdk#16498, fixed in the SDK by #16505); the source now checks before
  trusting it and throws `ProtectedDataUnavailable`, so `SessionAuthenticator` neither exchanges
  nor opens an anonymous session over the person's account.
- `errSecInteractionNotAllowed` is thrown as `ProtectedDataUnavailable`, in place of
  `FirebaseKeychainError.keychainFailed(status: -25308)`.

### Added

- `FirebaseKeychainLegacySessionSource(…, protectedData:)`, `KeychainProtectedDataProbe` by
  default.

### Changed

- Requires swift-authentication 12.1.0, for `ProtectedDataAvailability` and
  `ProtectedDataUnavailable`.

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
