import SwiftlaneDSL
import SwiftlaneMatch

// Example: Using Match to sync code signing
let signingLane = Lane(name: "sign") {
    // Sync development certificates and profiles for specific app
    match(
        type: .development,
        appIdentifier: "com.example.app"
    )
}

// Example: Sync App Store certificates in readonly mode
let releaseLane = Lane(name: "release") {
    match(
        type: .appstore,
        appIdentifier: "com.example.app",
        readonly: true
    )

    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .appStore
    )
}

// Example: Register devices from file and sync ad-hoc profiles
let adhocLane = Lane(name: "adhoc") {
    // Register new devices
    registerDevices(file: "devices.txt")

    // Sync ad-hoc profiles (force regeneration for new devices)
    match(
        type: .adhoc,
        appIdentifier: "com.example.app",
        forceForNewDevices: true
    )

    gym(
        scheme: "MyApp",
        configuration: .release,
        exportMethod: .adHoc
    )
}

// Example: Register devices from dictionary
let registerLane = Lane(name: "register") {
    registerDevices(devices: [
        "John's iPhone": "00008030-001234567890401E",
        "Jane's iPad": "00008101-000123456789012E",
        "Test Device": "00008020-001A1B2C3D4E501F"
    ])
}

// Example: Match with custom Git URL and branch
let customLane = Lane(name: "custom_sign") {
    match(
        type: .distribution,
        appIdentifier: "com.example.app",
        teamId: "TEAM123",
        gitUrl: "https://github.com/example/certificates.git",
        branch: "develop"
    )
}

// Example: Multiple apps in one lane
let multiAppLane = Lane(name: "multi_app") {
    // Sync profiles for main app
    match(
        type: .appstore,
        appIdentifier: "com.example.app"
    )

    // Sync profiles for watch app
    match(
        type: .appstore,
        appIdentifier: "com.example.app.watchkitapp"
    )

    // Sync profiles for app extension
    match(
        type: .appstore,
        appIdentifier: "com.example.app.extension"
    )
}
