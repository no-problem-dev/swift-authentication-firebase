English | [日本語](./README.ja.md)

# swift-authentication-firebase

Firebase Authentication for [swift-authentication](https://github.com/no-problem-dev/swift-authentication), **for moving apps off Firebase only. New apps do not use it.**

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

swift-authentication signs in with sessions the app's own server issues (`SessionAuthenticator`). This package holds what an app that used Firebase Authentication needs while it moves:

| Type | Use |
|---|---|
| `FirebaseLegacySessionSource` | Hand it to `SessionAuthenticator(legacySource:)`. On a device with no session yet, the Firebase user's ID token is exchanged once at the server's `/v1/auth/firebase`; the person keeps their uid, and the Firebase session is signed out afterwards. |
| `FirebaseAuthenticator`, `FirebaseTokenProvider`, `FirebaseConfigurator` | The Firebase implementations that lived in swift-authentication 10.x, for apps that have not moved yet. |

## Moving an app

```swift
import AuthenticationSession
import AuthenticationFirebase
import FirebaseCore
import FirebaseAuth

let authenticator = SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    legacySource: FirebaseLegacySessionSource {
        // Only devices without a session reach this, so new users never start Firebase.
        if FirebaseApp.app() == nil {
            FirebaseConfigurator.configure(sessionAfterReinstall: .keep)
        }
        return Auth.auth()
    },
    accountDeletionPath: "v1/account"
)
```

When the exchange fails — no network — `establishSession()` throws instead of opening a new anonymous user, and the app tries again later. Once old versions of the app are rare enough, remove this package.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication-firebase.git", from: "1.0.0")
]
```

## Requirements

| Swift | Platforms |
|---|---|
| 6.2 | iOS 17+ · macOS 14+ |

## License

MIT License. See [LICENSE](LICENSE) for details.
