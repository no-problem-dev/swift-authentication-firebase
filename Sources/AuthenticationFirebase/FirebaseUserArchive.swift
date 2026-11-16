import Foundation

/// Reads the keyed archive of `FIRUser` that Firebase Authentication keeps in the keychain,
/// without the SDK's classes.
///
/// The archive names Firebase's classes; each is decoded into a small class of ours that reads
/// only what the move needs. Class names and keys are those of firebase-ios-sdk 12.x
/// (`@objc(FIRUser)` in `User/User.swift`, `@objc(FIRSecureTokenService)` in
/// `SystemService/SecureTokenService.swift`, `@objc(FIRUserInfoImpl)` in
/// `User/UserInfoImpl.swift`), kept from the Objective-C SDK "for decoding old versions".
/// Everything else in the archive — metadata, multi-factor — is never decoded, so its classes do
/// not matter.
enum FirebaseUserArchive {
    static func decode(_ data: Data, key: String) throws -> FirebaseKeychainUser {
        let unarchiver: NSKeyedUnarchiver
        do {
            unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        } catch {
            throw FirebaseKeychainError.notAKeyedArchive(reason: String(describing: error))
        }
        defer { unarchiver.finishDecoding() }
        unarchiver.requiresSecureCoding = true
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        unarchiver.setClass(ArchivedUser.self, forClassName: "FIRUser")
        unarchiver.setClass(ArchivedTokenService.self, forClassName: "FIRSecureTokenService")
        unarchiver.setClass(ArchivedUserInfo.self, forClassName: "FIRUserInfoImpl")

        let user = unarchiver.decodeObject(of: ArchivedUser.self, forKey: key)
        if let error = unarchiver.error {
            throw FirebaseKeychainError.unexpectedArchive(reason: String(describing: error))
        }
        guard let user else {
            throw FirebaseKeychainError.unexpectedArchive(reason: "no FIRUser under \(key)")
        }
        guard let uid = user.uid, !uid.isEmpty else {
            throw FirebaseKeychainError.unexpectedArchive(reason: "FIRUser has no userID")
        }
        guard let tokenService = user.tokenService else {
            throw FirebaseKeychainError.unexpectedArchive(reason: "FIRUser has no tokenService")
        }
        guard let refreshToken = tokenService.refreshToken, !refreshToken.isEmpty else {
            throw FirebaseKeychainError.unexpectedArchive(reason: "FIRSecureTokenService has no refreshToken")
        }
        return FirebaseKeychainUser(
            uid: uid,
            refreshToken: refreshToken,
            isAnonymous: user.isAnonymous,
            email: user.email,
            displayName: user.displayName,
            firebaseProviderIDs: user.providerData.values.compactMap(\.providerID).sorted()
        )
    }
}

/// `FIRUser`, as far as the move needs it. Never fails to initialize: a missing value is reported
/// by ``FirebaseUserArchive`` with what was missing.
final class ArchivedUser: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let uid: String?
    let isAnonymous: Bool
    let email: String?
    let displayName: String?
    let providerData: [String: ArchivedUserInfo]
    let tokenService: ArchivedTokenService?

    init?(coder: NSCoder) {
        uid = coder.decodeObject(of: NSString.self, forKey: "userID") as String?
        isAnonymous = coder.decodeBool(forKey: "anonymous")
        email = coder.decodeObject(of: NSString.self, forKey: "email") as String?
        displayName = coder.decodeObject(of: NSString.self, forKey: "displayName") as String?
        providerData = coder.decodeObject(
            of: [NSDictionary.self, NSString.self, ArchivedUserInfo.self],
            forKey: "providerData"
        ) as? [String: ArchivedUserInfo] ?? [:]
        tokenService = coder.decodeObject(of: ArchivedTokenService.self, forKey: "tokenService")
    }

    func encode(with coder: NSCoder) {
        preconditionFailure("only decoded")
    }
}

/// `FIRSecureTokenService`: the refresh token.
final class ArchivedTokenService: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let refreshToken: String?

    init?(coder: NSCoder) {
        refreshToken = coder.decodeObject(of: NSString.self, forKey: "refreshToken") as String?
    }

    func encode(with coder: NSCoder) {
        preconditionFailure("only decoded")
    }
}

/// `FIRUserInfoImpl`: one linked provider.
final class ArchivedUserInfo: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }

    let providerID: String?

    init?(coder: NSCoder) {
        providerID = coder.decodeObject(of: NSString.self, forKey: "providerID") as String?
    }

    func encode(with coder: NSCoder) {
        preconditionFailure("only decoded")
    }
}
