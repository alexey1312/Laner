// swift-tools-version: 6.0

import PackageDescription

// Enable warnings-as-errors for stricter builds
// SwiftlaneMatch is excluded due to unavoidable SecKeychain deprecation warnings
// Usage: SWIFTLANE_STRICT=1 swift build
let warningsAsErrors: [SwiftSetting] = [
    .unsafeFlags(["-warnings-as-errors"])
]

let package = Package(
    name: "Swiftlane",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "swiftlane", targets: ["swiftlane"]),
        .library(name: "SwiftlaneDSL", targets: ["SwiftlaneDSL"]),
        .library(name: "SwiftlaneKit", targets: ["SwiftlaneKit"]),
        .library(name: "SwiftlanePluginKit", targets: ["SwiftlanePluginKit"]),
        .library(name: "SwiftlaneMatch", targets: ["SwiftlaneMatch"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.20.0"),
    ],
    targets: [
        // Executable
        .executableTarget(
            name: "swiftlane",
            dependencies: [
                "SwiftlaneCore",
                "SwiftlaneKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Internal implementation
        .target(
            name: "SwiftlaneCore",
            dependencies: [
                "SwiftlaneDSL",
                "SwiftlaneKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Public DSL API
        .target(
            name: "SwiftlaneDSL",
            dependencies: [
                "SwiftlaneKit",
                "SwiftlaneMatch",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Shared utilities
        .target(
            name: "SwiftlaneKit",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Plugin development kit
        .target(
            name: "SwiftlanePluginKit",
            dependencies: [
                "SwiftlaneDSL",
                "SwiftlaneKit",
            ],
            swiftSettings: warningsAsErrors
        ),

        // Match code signing module
        .target(
            name: "SwiftlaneMatch",
            dependencies: [
                "SwiftlaneKit",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                // Suppress deprecation warnings for SecKeychain APIs which are deprecated
                // but have no modern replacement for CI/CD code signing workflows
                .unsafeFlags(["-suppress-warnings"], .when(platforms: [.macOS]))
            ]
        ),

        // Tests
        .testTarget(
            name: "SwiftlaneKitTests",
            dependencies: ["SwiftlaneKit"],
            swiftSettings: warningsAsErrors
        ),
        .testTarget(
            name: "SwiftlaneDSLTests",
            dependencies: ["SwiftlaneDSL"],
            swiftSettings: warningsAsErrors
        ),
        .testTarget(
            name: "SwiftlaneCoreTests",
            dependencies: ["SwiftlaneCore"],
            swiftSettings: warningsAsErrors
        ),
        .testTarget(
            name: "SwiftlaneMatchTests",
            dependencies: ["SwiftlaneMatch"],
            swiftSettings: warningsAsErrors
        ),
    ]
)
