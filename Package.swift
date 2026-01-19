// swift-tools-version: 6.0

import PackageDescription

// Enable warnings-as-errors for stricter builds
// LanerMatch is excluded due to unavoidable SecKeychain deprecation warnings
// Usage: LANER_STRICT=1 swift build
let warningsAsErrors: [SwiftSetting] = [
    .unsafeFlags(["-warnings-as-errors"]),
]

let package = Package(
    name: "Laner",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "laner", targets: ["laner"]),
        .library(name: "LanerDSL", targets: ["LanerDSL"]),
        .library(name: "LanerKit", targets: ["LanerKit"]),
        .library(name: "LanerPluginKit", targets: ["LanerPluginKit"]),
        .library(name: "LanerMatch", targets: ["LanerMatch"]),
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
            name: "laner",
            dependencies: [
                "LanerCore",
                "LanerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Internal implementation
        .target(
            name: "LanerCore",
            dependencies: [
                "LanerDSL",
                "LanerKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Public DSL API
        .target(
            name: "LanerDSL",
            dependencies: [
                "LanerKit",
                "LanerMatch",
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Shared utilities
        .target(
            name: "LanerKit",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: warningsAsErrors
        ),

        // Plugin development kit
        .target(
            name: "LanerPluginKit",
            dependencies: [
                "LanerDSL",
                "LanerKit",
            ],
            swiftSettings: warningsAsErrors
        ),

        // Match code signing module
        .target(
            name: "LanerMatch",
            dependencies: [
                "LanerKit",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
            ],
            swiftSettings: [
                // Suppress deprecation warnings for SecKeychain APIs which are deprecated
                // but have no modern replacement for CI/CD code signing workflows
                .unsafeFlags(["-suppress-warnings"], .when(platforms: [.macOS])),
            ]
        ),

        // Tests
        .testTarget(
            name: "LanerKitTests",
            dependencies: ["LanerKit"],
            swiftSettings: warningsAsErrors
        ),
        .testTarget(
            name: "LanerDSLTests",
            dependencies: ["LanerDSL"],
            swiftSettings: warningsAsErrors
        ),
        .testTarget(
            name: "LanerCoreTests",
            dependencies: ["LanerCore"],
            swiftSettings: warningsAsErrors
        ),
        .testTarget(
            name: "LanerMatchTests",
            dependencies: ["LanerMatch"],
            swiftSettings: warningsAsErrors
        ),
    ]
)
