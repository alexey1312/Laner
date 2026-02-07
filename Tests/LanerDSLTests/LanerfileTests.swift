import Foundation
@testable import LanerDSL
import Testing

@Suite("Lanerfile.Module Tests")
struct LanerfileModuleTests {
    @Test("Module lane lookup by name")
    func moduleLaneLookup() {
        let module = Lanerfile.Module(lanes: [
            Lanerfile.Lane(
                name: "build",
                description: "Builds the app",
                actions: []
            ),
            Lanerfile.Lane(
                name: "test",
                description: "Runs tests",
                actions: []
            ),
        ])

        let found = module.lane(named: "build")
        #expect(found != nil)
        #expect(found?.name == "build")
        #expect(found?.description == "Builds the app")

        let notFound = module.lane(named: "nonexistent")
        #expect(notFound == nil)
    }

    @Test("Module laneNames returns all names")
    func moduleLaneNames() {
        let module = Lanerfile.Module(lanes: [
            Lanerfile.Lane(name: "build", description: "", actions: []),
            Lanerfile.Lane(name: "test", description: "", actions: []),
            Lanerfile.Lane(name: "deploy", description: "", actions: []),
        ])

        #expect(module.laneNames == ["build", "test", "deploy"])
    }

    @Test("Empty module has no lanes")
    func emptyModuleHasNoLanes() {
        let module = Lanerfile.Module(lanes: [])

        #expect(module.lanes.isEmpty)
        #expect(module.laneNames.isEmpty)
        #expect(module.lane(named: "any") == nil)
    }
}
