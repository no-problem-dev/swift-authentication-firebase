# Changelog

All notable changes to this project are recorded in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
