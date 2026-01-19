#if os(macOS)
    import Foundation

    /// Options for testing an Xcode project or workspace.
    public struct TestOptions: Sendable {
        /// The path to the project file (.xcodeproj).
        public var project: String?

        /// The path to the workspace file (.xcworkspace).
        public var workspace: String?

        /// The scheme to test.
        public var scheme: String?

        /// The build configuration (e.g., "Debug", "Release").
        public var configuration: String?

        /// The destination for tests (e.g., "platform=iOS Simulator,name=iPhone 15").
        public var destination: String?

        /// The derived data path.
        public var derivedDataPath: String?

        /// The result bundle path.
        public var resultBundlePath: String?

        /// Additional xcodebuild arguments.
        public var extraArguments: [String]

        /// Whether to test without building.
        public var testWithoutBuilding: Bool

        /// Specific test identifiers to run (e.g., "MyTests/testExample").
        public var onlyTesting: [String]

        /// Test identifiers to skip.
        public var skipTesting: [String]

        /// Creates test options.
        public init(
            project: String? = nil,
            workspace: String? = nil,
            scheme: String? = nil,
            configuration: String? = nil,
            destination: String? = nil,
            derivedDataPath: String? = nil,
            resultBundlePath: String? = nil,
            extraArguments: [String] = [],
            testWithoutBuilding: Bool = false,
            onlyTesting: [String] = [],
            skipTesting: [String] = []
        ) {
            self.project = project
            self.workspace = workspace
            self.scheme = scheme
            self.configuration = configuration
            self.destination = destination
            self.derivedDataPath = derivedDataPath
            self.resultBundlePath = resultBundlePath
            self.extraArguments = extraArguments
            self.testWithoutBuilding = testWithoutBuilding
            self.onlyTesting = onlyTesting
            self.skipTesting = skipTesting
        }

        /// Converts the options to xcodebuild command arguments.
        public func toArguments() -> [String] {
            var args: [String] = []

            if let workspace {
                args += ["-workspace", workspace]
            } else if let project {
                args += ["-project", project]
            }

            if let scheme {
                args += ["-scheme", scheme]
            }

            if let configuration {
                args += ["-configuration", configuration]
            }

            if let destination {
                args += ["-destination", destination]
            }

            if let derivedDataPath {
                args += ["-derivedDataPath", derivedDataPath]
            }

            if let resultBundlePath {
                args += ["-resultBundlePath", resultBundlePath]
            }

            for test in onlyTesting {
                args += ["-only-testing", test]
            }

            for test in skipTesting {
                args += ["-skip-testing", test]
            }

            if testWithoutBuilding {
                args.append("test-without-building")
            } else {
                args.append("test")
            }

            args += extraArguments

            return args
        }
    }
#endif
