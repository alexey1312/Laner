#if os(macOS)
    import Foundation

    /// Options for building an Xcode project or workspace.
    public struct BuildOptions: Sendable {
        /// The path to the project file (.xcodeproj).
        public var project: String?

        /// The path to the workspace file (.xcworkspace).
        public var workspace: String?

        /// The scheme to build.
        public var scheme: String?

        /// The build configuration (e.g., "Debug", "Release").
        public var configuration: String?

        /// The destination for the build (e.g., "platform=iOS Simulator,name=iPhone 15").
        public var destination: String?

        /// The derived data path.
        public var derivedDataPath: String?

        /// Additional xcodebuild arguments.
        public var extraArguments: [String]

        /// Whether to build for testing.
        public var buildForTesting: Bool

        /// Whether to perform a clean build.
        public var clean: Bool

        /// Creates build options.
        public init(
            project: String? = nil,
            workspace: String? = nil,
            scheme: String? = nil,
            configuration: String? = nil,
            destination: String? = nil,
            derivedDataPath: String? = nil,
            extraArguments: [String] = [],
            buildForTesting: Bool = false,
            clean: Bool = false
        ) {
            self.project = project
            self.workspace = workspace
            self.scheme = scheme
            self.configuration = configuration
            self.destination = destination
            self.derivedDataPath = derivedDataPath
            self.extraArguments = extraArguments
            self.buildForTesting = buildForTesting
            self.clean = clean
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

            if clean {
                args.append("clean")
            }

            if buildForTesting {
                args.append("build-for-testing")
            } else {
                args.append("build")
            }

            args += extraArguments

            return args
        }
    }
#endif
