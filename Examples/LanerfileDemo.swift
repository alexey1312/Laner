#!/usr/bin/env swift

// Example demonstrating Lanerfile usage
// Run with: swift Examples/LanerfileDemo.swift

import Foundation

// This would normally be: import LanerDSL
// For demo purposes, we'll show the structure

print("Lanerfile Demo")
print("==================")
print()

// Example 1: Creating a Lanerfile
print("1. Creating a Lanerfile with lanes:")
print("""
let manifest = Lanerfile(lanes: [
    Lane(name: "build", description: "Builds the iOS app") { context in
        // Build actions here
    },
    Lane(name: "test", description: "Runs unit tests") { context in
        // Test actions here
    },
    Lane(name: "deploy", description: "Deploys to App Store") { context in
        // Deploy actions here
    }
])
""")
print()

// Example 2: Looking up lanes
print("2. Looking up a lane by name:")
print("""
if let buildLane = manifest.lane(named: "build") {
    print("Found lane: \\(buildLane.name)")
    print("Description: \\(buildLane.description)")
    await runner.run(buildLane)
}
""")
print()

// Example 3: Getting all lane names
print("3. Getting all lane names:")
print("""
let names = manifest.laneNames
print("Available lanes: \\(names)")
// Output: Available lanes: ["build", "test", "deploy"]
""")
print()

// Example 4: Serialization
print("4. Serializing to JSON (metadata only):")
print("""
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
let jsonData = try encoder.encode(manifest)
let json = String(data: jsonData, encoding: .utf8)!
print(json)

// Output:
// {
//   "lanes" : [
//     {
//       "description" : "Builds the iOS app",
//       "name" : "build"
//     },
//     {
//       "description" : "Runs unit tests",
//       "name" : "test"
//     },
//     {
//       "description" : "Deploys to App Store",
//       "name" : "deploy"
//     }
//   ]
// }
""")
print()

// Example 5: Lane metadata
print("5. Extracting lane metadata:")
print("""
let metadata = manifest.metadata
for meta in metadata {
    print("Lane: \\(meta.name) - \\(meta.description)")
}

// Output:
// Lane: build - Builds the iOS app
// Lane: test - Runs unit tests
// Lane: deploy - Deploys to App Store
""")
print()

print("Key Features:")
print("- Lanerfile is the root manifest type")
print("- Stores lanes with their execution closures")
print("- Supports lane lookup by name")
print("- Can serialize to JSON (metadata only)")
print("- LaneMetadata provides Codable representation")
print("- All types are Sendable for Swift 6 concurrency")
