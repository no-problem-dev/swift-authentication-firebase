[English](./README.md) | 日本語

# swift-authentication-firebase

[swift-authentication](https://github.com/no-problem-dev/swift-authentication) で使う Firebase Authentication。**Firebase から移す間だけ使う。新しいアプリは使わない。**

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

swift-authentication は、アプリのサーバーが発行するセッションでサインインする（`SessionAuthenticator`）。このパッケージは、Firebase Authentication を使っていたアプリが移す間に要る物だけを持つ。

| 型 | 使い方 |
|---|---|
| `FirebaseLegacySessionSource` | `SessionAuthenticator(legacySource:)` に渡す。まだセッションの無い端末で、Firebase のユーザーの ID トークンをサーバーの `/v1/auth/firebase` で1回だけ交換する。uid はそのまま引き継ぎ、交換の後は Firebase からサインアウトする |
| `FirebaseAuthenticator`・`FirebaseTokenProvider`・`FirebaseConfigurator` | swift-authentication 10.x にあった Firebase の実装。まだ移していないアプリ用 |

## アプリを移す

```swift
import AuthenticationSession
import AuthenticationFirebase
import FirebaseCore
import FirebaseAuth

let authenticator = SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    legacySource: FirebaseLegacySessionSource {
        // ここに来るのはセッションの無い端末だけ。新しい人は Firebase を起動しない
        if FirebaseApp.app() == nil {
            FirebaseConfigurator.configure(sessionAfterReinstall: .keep)
        }
        return Auth.auth()
    },
    accountDeletionPath: "v1/account"
)
```

交換に失敗したとき（通信が無いなど）、`establishSession()` は新しい匿名ユーザーを作らずにエラーを投げる。アプリは後でやり直す。古いバージョンのアプリが十分に減ったら、このパッケージを外す。

## インストール

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication-firebase.git", from: "1.0.0")
]
```

## 動作環境

| Swift | プラットフォーム |
|---|---|
| 6.2 | iOS 17+ · macOS 14+ |

## ライセンス

MIT License。詳細は [LICENSE](LICENSE) を参照。
