import Foundation

/// Writes the keychain item Firebase Authentication writes, the way it writes it.
///
/// Each class copies `encode(with:)` of its firebase-ios-sdk 12.x counterpart, key for key and in
/// the same order (`User/User.swift`, `SystemService/SecureTokenService.swift`,
/// `User/UserInfoImpl.swift`, `User/UserMetadata.swift`, `MultiFactor/MultiFactor.swift`,
/// `MultiFactor/Phone/PhoneMultiFactorInfo.swift`), and is archived under the SDK's class name.
/// `Auth.saveUser(_:)` archives the user with `NSKeyedArchiver(requiringSecureCoding: true)`
/// under the key `<app name>_firebase_user`.
enum FirebaseArchiveFixture {
    struct Provider {
        var providerID: String
        var uid: String
        var email: String?
        var displayName: String?
    }

    static func userArchive(
        key: String = "__FIRAPP_DEFAULT_firebase_user",
        uid: String? = "firebase-uid-1",
        isAnonymous: Bool = false,
        email: String? = "person@example.com",
        displayName: String? = "Person",
        providers: [Provider] = [Provider(providerID: "apple.com", uid: "apple-sub", email: "person@example.com", displayName: nil)],
        refreshToken: String? = "AMf-refresh-token",
        withTokenService: Bool = true,
        withEnrolledFactor: Bool = false,
        userClassName: String = "FIRUser",
        requiringSecureCoding: Bool = true
    ) -> Data {
        let tokenService = withTokenService ? SecureTokenServiceFixture(refreshToken: refreshToken) : nil
        let user = UserFixture(
            uid: uid,
            isAnonymous: isAnonymous,
            email: email,
            displayName: displayName,
            providerData: Dictionary(uniqueKeysWithValues: providers.map { ($0.providerID, UserInfoFixture($0)) }),
            tokenService: tokenService,
            multiFactor: MultiFactorFixture(enrolledFactors: withEnrolledFactor ? [PhoneMultiFactorInfoFixture()] : [])
        )
        let archiver = NSKeyedArchiver(requiringSecureCoding: requiringSecureCoding)
        archiver.setClassName(userClassName, for: UserFixture.self)
        archiver.setClassName("FIRSecureTokenService", for: SecureTokenServiceFixture.self)
        archiver.setClassName("FIRUserInfoImpl", for: UserInfoFixture.self)
        archiver.setClassName("FIRUserMetadata", for: UserMetadataFixture.self)
        archiver.setClassName("FIRMultiFactor", for: MultiFactorFixture.self)
        archiver.setClassName("FIRPhoneMultiFactorInfo", for: PhoneMultiFactorInfoFixture.self)
        archiver.encode(user, forKey: key)
        archiver.finishEncoding()
        return archiver.encodedData
    }
}

final class UserFixture: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let uid: String?
    let isAnonymous: Bool
    let email: String?
    let displayName: String?
    let providerData: [String: UserInfoFixture]
    let tokenService: SecureTokenServiceFixture?
    let multiFactor: MultiFactorFixture
    let metadata = UserMetadataFixture()

    init(uid: String?, isAnonymous: Bool, email: String?, displayName: String?, providerData: [String: UserInfoFixture], tokenService: SecureTokenServiceFixture?, multiFactor: MultiFactorFixture) {
        self.uid = uid
        self.isAnonymous = isAnonymous
        self.email = email
        self.displayName = displayName
        self.providerData = providerData
        self.tokenService = tokenService
        self.multiFactor = multiFactor
    }

    required init?(coder: NSCoder) { nil }

    // User.encode(with:)
    func encode(with coder: NSCoder) {
        coder.encode(uid, forKey: "userID")
        coder.encode(isAnonymous, forKey: "anonymous")
        coder.encode(false, forKey: "hasEmailPassword")
        coder.encode(providerData, forKey: "providerData")
        coder.encode(email, forKey: "email")
        coder.encode(nil as String?, forKey: "phoneNumber")
        coder.encode(true, forKey: "emailVerified")
        coder.encode(URL(string: "https://example.com/photo.png"), forKey: "photoURL")
        coder.encode(displayName, forKey: "displayName")
        coder.encode(metadata, forKey: "metadata")
        coder.encode(nil as String?, forKey: "tenantID")
        coder.encode("AIza-api-key", forKey: "APIKey")
        coder.encode("1:1234567890:ios:abcdef", forKey: "firebaseAppID")
        coder.encode(tokenService, forKey: "tokenService")
        coder.encode(multiFactor, forKey: "multiFactor")
    }
}

final class SecureTokenServiceFixture: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let refreshToken: String?
    init(refreshToken: String?) { self.refreshToken = refreshToken }
    required init?(coder: NSCoder) { nil }

    // SecureTokenService.encode(with:)
    func encode(with coder: NSCoder) {
        coder.encode("AIza-api-key", forKey: "APIKey")
        coder.encode(refreshToken, forKey: "refreshToken")
        coder.encode("eyJ-access-token", forKey: "accessToken")
        coder.encode(Date(timeIntervalSince1970: 1_800_000_000), forKey: "accessTokenExpirationDate")
    }
}

final class UserInfoFixture: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let provider: FirebaseArchiveFixture.Provider
    init(_ provider: FirebaseArchiveFixture.Provider) { self.provider = provider }
    required init?(coder: NSCoder) { nil }

    // UserInfoImpl.encode(with:)
    func encode(with coder: NSCoder) {
        coder.encode(provider.providerID, forKey: "providerID")
        coder.encode(provider.uid, forKey: "userID")
        coder.encode(provider.displayName, forKey: "displayName")
        coder.encode(nil as URL?, forKey: "photoURL")
        coder.encode(provider.email, forKey: "email")
        coder.encode(nil as String?, forKey: "phoneNumber")
    }
}

final class UserMetadataFixture: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    override init() {}
    required init?(coder: NSCoder) { nil }

    // UserMetadata.encode(with:)
    func encode(with coder: NSCoder) {
        coder.encode(Date(timeIntervalSince1970: 1_700_000_000), forKey: "creationDate")
        coder.encode(Date(timeIntervalSince1970: 1_750_000_000), forKey: "lastSignInDate")
    }
}

final class MultiFactorFixture: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let enrolledFactors: [PhoneMultiFactorInfoFixture]
    init(enrolledFactors: [PhoneMultiFactorInfoFixture]) { self.enrolledFactors = enrolledFactors }
    required init?(coder: NSCoder) { nil }

    // MultiFactor.encode(with:)
    func encode(with coder: NSCoder) {
        coder.encode(enrolledFactors, forKey: "enrolledFactors")
    }
}

final class PhoneMultiFactorInfoFixture: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    override init() {}
    required init?(coder: NSCoder) { nil }

    // MultiFactorInfo.encode(with:), then PhoneMultiFactorInfo's phoneNumber
    func encode(with coder: NSCoder) {
        coder.encode("factor-uid", forKey: "uid")
        coder.encode("Phone", forKey: "displayName")
        coder.encode(Date(timeIntervalSince1970: 1_700_000_000), forKey: "enrollmentDate")
        coder.encode("phone", forKey: "factorID")
        coder.encode("+15555550100", forKey: "phoneNumber")
    }
}
