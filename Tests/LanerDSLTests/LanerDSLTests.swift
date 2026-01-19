import Foundation
@testable import LanerDSL
import Logging
import Testing

// MARK: - Test Helpers

/// A simple test action for unit tests.
struct EchoAction: Action {
    typealias Options = String
    typealias Result = String

    static let name = "echo"
    static let description = "Echoes a message"

    let message: String

    @MainActor
    func execute(context: ExecutionContext) async throws -> String {
        context.logger.info("Echo: \(message)")
        return message
    }
}

/// An action that always fails for testing error handling.
struct FailingAction: Action {
    typealias Options = Void
    typealias Result = Void

    static let name = "fail"
    static let description = "Always fails"

    struct ActionError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    let errorMessage: String

    @MainActor
    func execute(context: ExecutionContext) async throws {
        throw ActionError(message: errorMessage)
    }
}

/// An action that adds an artifact.
struct ArtifactAction: Action {
    typealias Options = Void
    typealias Result = Void

    static let name = "artifact"
    static let description = "Adds an artifact"

    let artifactType: ArtifactType
    let path: URL

    @MainActor
    func execute(context: ExecutionContext) async throws {
        let artifact = Artifact(type: artifactType, path: path)
        await context.addArtifact(artifact)
    }
}

// MARK: - Environment Tests

@Suite("Environment Tests")
struct EnvironmentTests {
    @Test("detects GitHub Actions")
    func detectsGitHubActions() {
        let env = Environment(variables: ["GITHUB_ACTIONS": "true"])
        #expect(env.isCI)
        #expect(env.ciProvider == .githubActions)
    }

    @Test("detects GitLab CI")
    func detectsGitLabCI() {
        let env = Environment(variables: ["GITLAB_CI": "true"])
        #expect(env.isCI)
        #expect(env.ciProvider == .gitlabCI)
    }

    @Test("detects Jenkins")
    func detectsJenkins() {
        let env = Environment(variables: ["JENKINS_URL": "http://jenkins.example.com"])
        #expect(env.isCI)
        #expect(env.ciProvider == .jenkins)
    }

    @Test("detects local development")
    func detectsLocalDevelopment() {
        let env = Environment(variables: [:])
        #expect(!env.isCI)
        #expect(env.ciProvider == nil)
    }

    @Test("accesses environment variables")
    func accessesEnvironmentVariables() {
        let env = Environment(variables: ["FOO": "bar", "BAZ": "qux"])
        #expect(env["FOO"] == "bar")
        #expect(env["BAZ"] == "qux")
        #expect(env["MISSING"] == nil)
    }

    @Test("gets default value for missing variable")
    func getsDefaultValue() {
        let env = Environment(variables: [:])
        #expect(env.get("MISSING", default: "default") == "default")
    }

    @Test("requires variable throws when missing")
    func requireVariableThrows() throws {
        let env = Environment(variables: [:])
        #expect(throws: EnvironmentError.self) {
            _ = try env.require("MISSING")
        }
    }

    @Test("parses boolean values")
    func parsesBooleanValues() {
        let env = Environment(variables: [
            "TRUE1": "true",
            "TRUE2": "1",
            "TRUE3": "yes",
            "TRUE4": "ON",
            "FALSE1": "false",
            "FALSE2": "0",
        ])
        #expect(env.getBool("TRUE1"))
        #expect(env.getBool("TRUE2"))
        #expect(env.getBool("TRUE3"))
        #expect(env.getBool("TRUE4"))
        #expect(!env.getBool("FALSE1"))
        #expect(!env.getBool("FALSE2"))
        #expect(!env.getBool("MISSING"))
    }

    @Test("parses integer values")
    func parsesIntegerValues() {
        let env = Environment(variables: ["PORT": "8080", "INVALID": "abc"])
        #expect(env.getInt("PORT") == 8080)
        #expect(env.getInt("INVALID") == nil)
        #expect(env.getInt("MISSING") == nil)
    }
}

// MARK: - Artifact Tests

@Suite("Artifact Tests")
struct ArtifactTests {
    @Test("creates artifact with defaults")
    func createsArtifactWithDefaults() {
        let url = URL(fileURLWithPath: "/tmp/app.ipa")
        let artifact = Artifact(type: .ipa, path: url)

        #expect(artifact.type == .ipa)
        #expect(artifact.path == url)
        #expect(artifact.name == "app.ipa")
        #expect(artifact.metadata.isEmpty)
    }

    @Test("creates artifact with custom name")
    func createsArtifactWithCustomName() {
        let url = URL(fileURLWithPath: "/tmp/app.ipa")
        let artifact = Artifact(type: .ipa, path: url, name: "MyApp Release")

        #expect(artifact.name == "MyApp Release")
    }

    @Test("creates artifact with metadata")
    func createsArtifactWithMetadata() {
        let url = URL(fileURLWithPath: "/tmp/app.ipa")
        let artifact = Artifact(type: .ipa, path: url, metadata: ["version": "1.0.0"])

        #expect(artifact.metadata["version"] == "1.0.0")
    }
}

// MARK: - ArtifactStore Tests

@Suite("ArtifactStore Tests")
struct ArtifactStoreTests {
    @Test("stores and retrieves artifacts")
    func storesAndRetrievesArtifacts() async {
        let store = ArtifactStore()
        let artifact = Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app.ipa"))

        await store.add(artifact)
        let all = await store.all()

        #expect(all.count == 1)
        #expect(all.first?.type == .ipa)
    }

    @Test("filters by type")
    func filtersByType() async {
        let store = ArtifactStore()
        await store.add(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app.ipa")))
        await store.add(Artifact(type: .dsym, path: URL(fileURLWithPath: "/tmp/app.dSYM")))
        await store.add(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app2.ipa")))

        let ipas = await store.artifacts(ofType: .ipa)
        let dsyms = await store.artifacts(ofType: .dsym)

        #expect(ipas.count == 2)
        #expect(dsyms.count == 1)
    }

    @Test("gets first artifact of type")
    func getsFirstArtifactOfType() async {
        let store = ArtifactStore()
        await store.add(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app1.ipa"), name: "first"))
        await store.add(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app2.ipa"), name: "second"))

        let first = await store.artifact(ofType: .ipa)
        #expect(first?.name == "first")
    }

    @Test("gets latest artifact of type")
    func getsLatestArtifactOfType() async {
        let store = ArtifactStore()
        await store.add(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app1.ipa"), name: "first"))
        await store.add(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app2.ipa"), name: "second"))

        let latest = await store.latestArtifact(ofType: .ipa)
        #expect(latest?.name == "second")
    }

    @Test("clears all artifacts")
    func clearsAllArtifacts() async {
        let store = ArtifactStore()
        await store.add(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app.ipa")))
        await store.clear()

        let all = await store.all()
        #expect(all.isEmpty)
    }
}

// MARK: - Action Tests

@Suite("Action Tests")
struct ActionTests {
    @Test("action has name and description")
    func actionHasNameAndDescription() {
        #expect(EchoAction.name == "echo")
        #expect(EchoAction.description == "Echoes a message")
    }

    @Test("action executes and returns result")
    @MainActor
    func actionExecutesAndReturnsResult() async throws {
        let action = EchoAction(message: "Hello, World!")
        let context = ExecutionContext()
        let result = try await action.execute(context: context)
        #expect(result == "Hello, World!")
    }
}

// MARK: - AnyAction Tests

@Suite("AnyAction Tests")
struct AnyActionTests {
    @Test("wraps action with name")
    func wrapsActionWithName() {
        let action = EchoAction(message: "test")
        let anyAction = AnyAction(action)

        #expect(anyAction.name == "echo")
        #expect(anyAction.description == "Echoes a message")
    }

    @Test("executes wrapped action")
    @MainActor
    func executesWrappedAction() async throws {
        let action = EchoAction(message: "wrapped")
        let anyAction = AnyAction(action)
        let context = ExecutionContext()

        try await anyAction.execute(context: context)
        // If we get here without throwing, the action executed
    }
}

// MARK: - Lane Tests

@Suite("Lane Tests")
struct LaneTests {
    @Test("creates lane with name and description")
    func createsLaneWithNameAndDescription() {
        let lane = Lane(name: "build", description: "Builds the app") { _ in }

        #expect(lane.name == "build")
        #expect(lane.description == "Builds the app")
    }

    @Test("creates lane from actions")
    func createsLaneFromActions() {
        let actions = [
            AnyAction(EchoAction(message: "step 1")),
            AnyAction(EchoAction(message: "step 2")),
        ]
        let lane = Lane(name: "multi", actions: actions)

        #expect(lane.name == "multi")
    }

    @Test("executes lane body")
    @MainActor
    func executesLaneBody() async throws {
        var executed = false
        let lane = Lane(name: "test") { _ in
            executed = true
        }
        let context = ExecutionContext()

        try await lane.execute(context: context)
        #expect(executed)
    }

    @Test("executes lane actions in order")
    @MainActor
    func executesLaneActionsInOrder() async throws {
        var order: [String] = []

        let lane = Lane(name: "ordered") { _ in
            order.append("first")
            order.append("second")
            order.append("third")
        }

        let context = ExecutionContext()
        try await lane.execute(context: context)

        #expect(order == ["first", "second", "third"])
    }
}

// MARK: - LaneRunner Tests

@Suite("LaneRunner Tests")
struct LaneRunnerTests {
    @Test("runs successful lane")
    @MainActor
    func runsSuccessfulLane() async {
        let lane = Lane(name: "success") { _ in
            // Do nothing - success
        }
        let runner = LaneRunner()
        let result = await runner.run(lane)

        #expect(result.success)
        #expect(result.laneName == "success")
        #expect(result.error == nil)
    }

    @Test("runs failing lane")
    @MainActor
    func runsFailingLane() async {
        struct TestError: Error {}
        let lane = Lane(name: "expectedFailure") { _ in
            throw TestError()
        }
        // Use a silent logger to avoid xcsift parsing the expected error log as a test failure
        var silentLogger = Logger(label: "test.silent")
        silentLogger.logLevel = .critical
        let runner = LaneRunner(logger: silentLogger)
        let result = await runner.run(lane)

        #expect(!result.success)
        #expect(result.laneName == "expectedFailure")
        #expect(result.error != nil)
    }

    @Test("collects artifacts from lane")
    @MainActor
    func collectsArtifactsFromLane() async {
        let lane = Lane(name: "artifacts") { context in
            await context.addArtifact(Artifact(type: .ipa, path: URL(fileURLWithPath: "/tmp/app.ipa")))
        }
        let runner = LaneRunner()
        let result = await runner.run(lane)

        #expect(result.artifacts.count == 1)
        #expect(result.artifacts.first?.type == .ipa)
    }

    @Test("tracks execution duration")
    @MainActor
    func tracksExecutionDuration() async {
        let lane = Lane(name: "timed") { _ in
            try? await Task.sleep(for: .milliseconds(50))
        }
        let runner = LaneRunner()
        let result = await runner.run(lane)

        let durationMS = Double(result.duration.components.seconds) * 1000 +
            Double(result.duration.components.attoseconds) / 1e15
        #expect(durationMS >= 50)
    }
}

// MARK: - ExecutionContext Tests

@Suite("ExecutionContext Tests")
struct ExecutionContextTests {
    @Test("provides environment")
    @MainActor
    func providesEnvironment() {
        let env = Environment(variables: ["TEST": "value"])
        let context = ExecutionContext(environment: env)

        #expect(context.environment["TEST"] == "value")
    }

    @Test("provides shell executor")
    @MainActor
    func providesShellExecutor() {
        let context = ExecutionContext()
        // Shell executor should be accessible
        _ = context.shell
    }

    @Test("provides working directory")
    @MainActor
    func providesWorkingDirectory() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let context = ExecutionContext(workingDirectory: url)

        #expect(context.workingDirectory == url)
    }

    @Test("provides parameters")
    @MainActor
    func providesParameters() {
        let context = ExecutionContext(parameters: ["key": "value"])

        let value: String? = context.parameter("key")
        #expect(value == "value")
    }

    @Test("requires missing parameter throws")
    @MainActor
    func requiresMissingParameterThrows() {
        let context = ExecutionContext()

        #expect(throws: ContextError.self) {
            let _: String = try context.requireParameter("missing")
        }
    }

    @Test("creates sub-context with new working directory")
    @MainActor
    func createsSubContextWithNewWorkingDirectory() {
        let original = ExecutionContext()
        let newDir = URL(fileURLWithPath: "/tmp/subdir")
        let subContext = original.withWorkingDirectory(newDir)

        #expect(subContext.workingDirectory == newDir)
    }

    @Test("creates sub-context with additional parameters")
    @MainActor
    func createsSubContextWithAdditionalParameters() {
        let original = ExecutionContext(parameters: ["a": "1"])
        let subContext = original.withParameters(["b": "2"])

        let a: String? = subContext.parameter("a")
        let b: String? = subContext.parameter("b")
        #expect(a == "1")
        #expect(b == "2")
    }
}

// MARK: - LanerConfiguration Tests

@Suite("LanerConfiguration Tests")
struct LanerConfigurationTests {
    struct TestConfig: LanerConfiguration {
        static var lanes: [Lane] {
            [
                Lane(name: "build", description: "Builds the app") { _ in },
                Lane(name: "test", description: "Runs tests") { _ in },
            ]
        }
    }

    @Test("finds lane by name")
    func findsLaneByName() {
        let lane = TestConfig.lane(named: "build")
        #expect(lane?.name == "build")
    }

    @Test("returns nil for missing lane")
    func returnsNilForMissingLane() {
        let lane = TestConfig.lane(named: "nonexistent")
        #expect(lane == nil)
    }

    @Test("validates unique lane names")
    func validatesUniqueLaneNames() throws {
        struct ValidConfig: LanerConfiguration {
            static var lanes: [Lane] {
                [
                    Lane(name: "a") { _ in },
                    Lane(name: "b") { _ in },
                ]
            }
        }
        try ValidConfig.validate() // Should not throw
    }

    @Test("throws for duplicate lane names")
    func throwsForDuplicateLaneNames() {
        struct DuplicateConfig: LanerConfiguration {
            static var lanes: [Lane] {
                [
                    Lane(name: "same") { _ in },
                    Lane(name: "same") { _ in },
                ]
            }
        }
        #expect(throws: ConfigurationError.self) {
            try DuplicateConfig.validate()
        }
    }

    @Test("runs lane by name")
    @MainActor
    func runsLaneByName() async throws {
        let result = try await TestConfig.runLane(named: "build")
        #expect(result.success)
        #expect(result.laneName == "build")
    }

    @Test("throws for missing lane name")
    @MainActor
    func throwsForMissingLaneName() async {
        await #expect(throws: ConfigurationError.self) {
            _ = try await TestConfig.runLane(named: "nonexistent")
        }
    }
}
