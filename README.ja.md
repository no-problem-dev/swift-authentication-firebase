[English](./README.md) | 日本語

# swift-authentication-firebase

Firebase Authentication でサインインしていた人を、[swift-authentication](https://github.com/no-problem-dev/swift-authentication) の `SessionAuthenticator` に移す。**Firebase の SDK は使わない。** 新しいアプリは使わない。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20%7C%20macOS%2014+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

`FirebaseKeychainLegacySessionSource` は、前のバージョンのアプリがキーチェーンに残したユーザーを読み、そのリフレッシュトークンを `SessionAuthenticator(legacySource:)` に渡す。認証は、サーバーの `/v1/auth/firebase` に `{ refreshToken, installId }` で1回だけ送る。サーバーが Google で ID トークンに替え、Firebase の uid をそのままユーザー ID にする。端末は Google と通信しないので、Google に届かない所でも移せる。交換の後はキーチェーンの項目を消す。

依存は Foundation・Security と swift-authentication の `Authentication` だけ。

## アプリを移す

```swift
import AuthenticationSession
import AuthenticationFirebase

let authenticator = SessionAuthenticator(
    baseURL: apiURL,
    installID: { InstallID.current },
    // 前のバージョンが入れていた GoogleService-Info.plist の GOOGLE_APP_ID
    legacySource: FirebaseKeychainLegacySessionSource(googleAppID: "1:1234567890:ios:abcdef"),
    accountDeletionPath: "v1/account"
)
```

- あとで通るかもしれない失敗（通信が無い・Google に届かずサーバーが 503・キーチェーンがまだ解錠されていない）では、`establishSession()` はエラーを投げ、新しいセッションを作らない。次の起動でやり直す
- サーバーが「二度と替えられない」と答えたとき（Google がリフレッシュトークンを断った）は、項目を消し、新しい端末と同じように始める
- `storedUser()` は通信せずに項目を読み、前のバージョンの uid・メール・表示名・つないだプロバイダを返す。交換が通信を待つ間も、サインインしたままに見せるのに使う
- 読めない項目は「ユーザーがいない」にせず、`FirebaseKeychainError`（`keychainFailed(status:)`・`notAKeyedArchive`・`unexpectedArchive`）で返す
- 端末の保護されたデータが使えない間（再起動後に一度もロックを解いていない間や、ロック中の事前起動・バックグラウンドでの起動）は、項目があってもキーチェーンが「見つからない」と答えることがある。「ユーザーがいない」と答える前に `ProtectedDataAvailability`（既定は `KeychainProtectedDataProbe`）に確かめ、使えなければ `ProtectedDataUnavailable` を投げる。`establishSession()` はそれをそのまま投げ、何も作らない。`UIApplication.protectedDataDidBecomeAvailableNotification` の後にもう一度呼ぶ

項目は SDK の物：サービス `firebase_auth_<GOOGLE_APP_ID>`、アカウント `firebase_auth_1_<アプリ名>_firebase_user`、中身は `FIRUser` の NSKeyedArchiver。接頭辞もサービスも無いアカウントは最も古い SDK が書いた物で、これも読む。共有のアクセスグループ（`Auth.useUserAccessGroup(_:)`）に置いたユーザーは読まない。

古いバージョンのアプリが十分に減ったら、このパッケージを外す。

## インストール

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-authentication-firebase.git", from: "2.1.0")
]
```

1.x の Firebase の `Authenticator`（`FirebaseAuthenticator`・`FirebaseTokenProvider`・`FirebaseConfigurator`）は無くした。まだ Firebase でサインインしているアプリは 1.x のまま使う。

## 動作環境

| Swift | プラットフォーム |
|---|---|
| 6.2 | iOS 17+ · macOS 14+ |

## ライセンス

MIT License。詳細は [LICENSE](LICENSE) を参照。
