import Testing
import Foundation
@testable import AuthenticationFirebase

@Suite("FirebaseKeychainUser redaction")
struct FirebaseKeychainUserRedactionTests {
    @Test("a stored user prints who it is and not the refresh token")
    func redacted() {
        let user = FirebaseKeychainUser(
            uid: "uid-1",
            refreshToken: "SECRET-REFRESH",
            isAnonymous: false,
            email: "a@example.com",
            displayName: "A",
            firebaseProviderIDs: ["apple.com"]
        )
        var dumped = ""
        dump(user, to: &dumped)
        for text in [String(describing: user), String(reflecting: user), "\(Optional(user) as Any)", dumped] {
            #expect(!text.contains("SECRET"), "\(text)")
            #expect(text.contains("uid-1"))
        }
    }
}
