// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AuthenticationFirebase",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // For apps moving off Firebase Authentication. New apps do not use it.
        .library(name: "AuthenticationFirebase", targets: ["AuthenticationFirebase"])
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "11.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "12.5.0")),
    ],
    targets: [
        .target(
            name: "AuthenticationFirebase",
            dependencies: [
                .product(name: "Authentication", package: "swift-authentication"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk")
            ],
            path: "Sources/AuthenticationFirebase",
            // The privacy manifest lives here, because this is the target that touches user
            // defaults. `.copy` puts it in the bundle verbatim.
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .testTarget(
            name: "AuthenticationFirebaseTests",
            dependencies: [
                "AuthenticationFirebase",
                .product(name: "Authentication", package: "swift-authentication")
            ],
            path: "Tests/AuthenticationFirebaseTests"
        )
    ]
)
