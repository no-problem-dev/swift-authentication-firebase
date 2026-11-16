import Foundation
@preconcurrency import FirebaseAuth
import Authentication

/// Converts a Firebase user into the vendor-neutral user value the core deals in.
enum FirebaseUserMapper {
    static func map(_ user: User) -> AuthUser {
        AuthUser(
            id: user.uid,
            email: user.email,
            displayName: user.displayName,
            isAnonymous: user.isAnonymous,
            providerIDs: user.providerData.map { providerID(firebase: $0.providerID) }
        )
    }

    /// The core's name for a provider, as Firebase names it.
    static func firebaseProviderID(_ providerID: Authentication.AuthProviderID) -> String {
        switch providerID {
        case .apple: "apple.com"
        case .google: "google.com"
        default: providerID.rawValue
        }
    }

    /// Firebase names providers by domain; the core uses the session server's names.
    static func providerID(firebase providerID: String) -> Authentication.AuthProviderID {
        switch providerID {
        case "apple.com": .apple
        case "google.com": .google
        default: Authentication.AuthProviderID(rawValue: providerID)
        }
    }
}
