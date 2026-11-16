English | [日本語](./README.ja.md)

# swift-authentication-firebase

Moves the people an app signed in with Firebase Authentication onto [swift-authentication](https://github.com/no-problem-dev/swift-authentication)'s `SessionAuthenticator` — **without the Firebase SDK**. New apps do not use it.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

`FirebaseKeychainLegacySessionSource` reads the user the earlier version of the app left in the keychain, and hands its refresh token to `SessionAuthenticator(legacySource:)`. The authenticator sends it once to the server's `/v1/auth/firebase` as `{ refreshToken, installId }`; the server trades it at Google for an ID token and keeps the Firebase uid as the user id. The device never talks to Google, so the move works where Google cannot be reached. Afterwards the keychain item is removed.

Depends on Foundation, Security and swift-authentication's `Authentication` only.

## Moving an app

```swift
import AuthenticationSession
import AuthenticationFirebase

let authenticator = SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    // GOOGLE_APP_ID from the GoogleService-Info.plist the earlier version shipped.
    legacySource: FirebaseKeychainLegacySessionSource(googleAppID: "1:1234567890:ios:abcdef"),
    accountDeletionPath: "v1/account"
)
```

- When the exchange may succeed later — no network, the server's 503 while Google is unreachable, a keychain still locked — `establishSession()` throws and opens no new session; the next launch tries again.
- When the server says it never will — Google refused the refresh token for good — the item is removed and the device starts as a new one would.
- `storedUser()` reads the item without a request: the uid, email, display name and linked providers the earlier version had. Use it to show the person as signed in while the exchange waits for the network.
- An item that cannot be read is reported as `FirebaseKeychainError` — `keychainFailed(status:)`, `notAKeyedArchive`, `unexpectedArchive` — never as "no user".

The item is the SDK's: service `firebase_auth_<GOOGLE_APP_ID>`, account `firebase_auth_1_<app name>_firebase_user`, holding a keyed archive of `FIRUser`; the account without the prefix and service is what the oldest SDKs wrote, and is read too. A user kept in a shared access group (`Auth.useUserAccessGroup(_:)`) is not read.

Once old versions of the app are rare enough, remove this package.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication-firebase.git", from: "2.0.0")
]
```

The Firebase `Authenticator` of 1.x (`FirebaseAuthenticator`, `FirebaseTokenProvider`, `FirebaseConfigurator`) is gone; an app that still signs in through Firebase stays on 1.x.

## Requirements

| Swift | Platforms |
|---|---|
| 6.2 | iOS 17+ · macOS 14+ |

## License

MIT License. See [LICENSE](LICENSE) for details.
