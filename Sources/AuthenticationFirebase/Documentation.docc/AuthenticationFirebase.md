# ``AuthenticationFirebase``

Moves the people an app signed in with Firebase Authentication onto `SessionAuthenticator`,
without the Firebase SDK. New apps do not use it.

## Overview

``FirebaseKeychainLegacySessionSource`` reads the `FIRUser` Firebase Authentication left in the
keychain and hands its refresh token to `SessionAuthenticator(legacySource:)`, which exchanges it
once at the session server's `/v1/auth/firebase`. The server trades the token at Google, so the
device never needs to reach Google, and keeps the Firebase uid as the user id.

```swift
SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    legacySource: FirebaseKeychainLegacySessionSource(googleAppID: "1:1234567890:ios:abcdef")
)
```

An item that cannot be read is reported as ``FirebaseKeychainError``, never as no user.

## Topics

- ``FirebaseKeychainLegacySessionSource``
- ``FirebaseKeychainUser``
- ``FirebaseKeychainError``
