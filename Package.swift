// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AuthenticationFirebase",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // For apps moving off Firebase Authentication. Reads what Firebase left on the device
        // without the Firebase SDK. New apps do not use it.
        .library(name: "AuthenticationFirebase", targets: ["AuthenticationFirebase"])
    ],
    dependencies: [
        .package(url: "https://github.com/no-problem-dev/swift-authentication.git", from: "12.0.0"),
    ],
    targets: [
        .target(
            name: "AuthenticationFirebase",
            dependencies: [
                .product(name: "Authentication", package: "swift-authentication")
            ],
            path: "Sources/AuthenticationFirebase"
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
