import Foundation
import Testing
@testable import SwiftlaneDSL

@Suite("Swiftlanefile Tests")
struct SwiftlanefileTests {
    @Test("Swiftlanefile stores and retrieves lanes")
    func swiftlanefileBasicFunctionality() async throws {
        // Create test lanes
        let buildLane = Lane(
            name: "build",
            description: "Builds the app"
        ) { _ in
            // Empty body for test
        }

        let testLane = Lane(
            name: "test",
            description: "Runs tests"
        ) { _ in
            // Empty body for test
        }

        // Create manifest
        let manifest = Swiftlanefile(lanes: [buildLane, testLane])

        // Verify lane count
        #expect(manifest.lanes.count == 2)

        // Verify lane names
        #expect(manifest.laneNames == ["build", "test"])

        // Verify lane lookup
        let foundBuild = manifest.lane(named: "build")
        #expect(foundBuild != nil)
        #expect(foundBuild?.name == "build")
        #expect(foundBuild?.description == "Builds the app")

        // Verify missing lane returns nil
        let notFound = manifest.lane(named: "nonexistent")
        #expect(notFound == nil)
    }

    @Test("LaneMetadata extracts lane information")
    func laneMetadataExtraction() async throws {
        let lane = Lane(
            name: "deploy",
            description: "Deploys to production"
        ) { _ in
            // Empty body
        }

        let metadata = LaneMetadata(from: lane)

        #expect(metadata.name == "deploy")
        #expect(metadata.description == "Deploys to production")
    }

    @Test("Swiftlanefile metadata returns all lane metadata")
    func swiftlanefileMetadata() async throws {
        let lanes = [
            Lane(name: "build", description: "Build") { _ in },
            Lane(name: "test", description: "Test") { _ in },
            Lane(name: "deploy", description: "Deploy") { _ in }
        ]

        let manifest = Swiftlanefile(lanes: lanes)
        let metadata = manifest.metadata

        #expect(metadata.count == 3)
        #expect(metadata[0].name == "build")
        #expect(metadata[1].name == "test")
        #expect(metadata[2].name == "deploy")
    }

    @Test("Swiftlanefile can be encoded to JSON")
    func swiftlanefileSerialization() async throws {
        let lanes = [
            Lane(name: "build", description: "Build the app") { _ in },
            Lane(name: "test", description: "Run tests") { _ in }
        ]

        let manifest = Swiftlanefile(lanes: lanes)

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(manifest)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Verify JSON contains expected structure
        #expect(jsonString.contains("\"lanes\""))
        #expect(jsonString.contains("\"build\""))
        #expect(jsonString.contains("\"Build the app\""))
        #expect(jsonString.contains("\"test\""))
        #expect(jsonString.contains("\"Run tests\""))
    }

    @Test("Swiftlanefile can be decoded from JSON")
    func swiftlanefileDeserialization() async throws {
        let json = """
        {
            "lanes": [
                {
                    "name": "build",
                    "description": "Build the app"
                },
                {
                    "name": "test",
                    "description": "Run tests"
                }
            ]
        }
        """

        let jsonData = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(Swiftlanefile.self, from: jsonData)

        #expect(manifest.lanes.count == 2)
        #expect(manifest.lanes[0].name == "build")
        #expect(manifest.lanes[0].description == "Build the app")
        #expect(manifest.lanes[1].name == "test")
        #expect(manifest.lanes[1].description == "Run tests")
    }

    @Test("Lane metadata is Hashable")
    func laneMetadataHashable() async throws {
        let metadata1 = LaneMetadata(name: "build", description: "Build")
        let metadata2 = LaneMetadata(name: "build", description: "Build")
        let metadata3 = LaneMetadata(name: "test", description: "Test")

        #expect(metadata1 == metadata2)
        #expect(metadata1 != metadata3)

        // Verify can be used in Set
        let metadataSet: Set<LaneMetadata> = [metadata1, metadata2, metadata3]
        #expect(metadataSet.count == 2) // metadata1 and metadata2 are equal
    }
}
