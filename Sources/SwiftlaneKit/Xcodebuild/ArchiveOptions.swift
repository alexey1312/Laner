#if os(macOS)
import Foundation

/// Options for archiving an Xcode project or workspace.
public struct ArchiveOptions: Sendable {
    /// The path to the project file (.xcodeproj).
    public var project: String?

    /// The path to the workspace file (.xcworkspace).
    public var workspace: String?

    /// The scheme to archive.
    public var scheme: String?

    /// The build configuration (e.g., "Debug", "Release").
    public var configuration: String?

    /// The archive path (.xcarchive).
    public var archivePath: String

    /// The derived data path.
    public var derivedDataPath: String?

    /// Additional xcodebuild arguments.
    public var extraArguments: [String]

    /// Creates archive options.
    public init(
        project: String? = nil,
        workspace: String? = nil,
        scheme: String? = nil,
        configuration: String? = nil,
        archivePath: String,
        derivedDataPath: String? = nil,
        extraArguments: [String] = []
    ) {
        self.project = project
        self.workspace = workspace
        self.scheme = scheme
        self.configuration = configuration
        self.archivePath = archivePath
        self.derivedDataPath = derivedDataPath
        self.extraArguments = extraArguments
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

        if let derivedDataPath {
            args += ["-derivedDataPath", derivedDataPath]
        }

        args += ["-archivePath", archivePath]
        args.append("archive")
        args += extraArguments

        return args
    }
}

/// Options for exporting an archive.
public struct ExportOptions: Sendable {
    /// The path to the archive (.xcarchive).
    public var archivePath: String

    /// The export destination path.
    public var exportPath: String

    /// The path to the export options plist.
    public var exportOptionsPlist: String

    /// Additional xcodebuild arguments.
    public var extraArguments: [String]

    /// Creates export options.
    public init(
        archivePath: String,
        exportPath: String,
        exportOptionsPlist: String,
        extraArguments: [String] = []
    ) {
        self.archivePath = archivePath
        self.exportPath = exportPath
        self.exportOptionsPlist = exportOptionsPlist
        self.extraArguments = extraArguments
    }

    /// Converts the options to xcodebuild command arguments.
    public func toArguments() -> [String] {
        var args: [String] = [
            "-exportArchive",
            "-archivePath", archivePath,
            "-exportPath", exportPath,
            "-exportOptionsPlist", exportOptionsPlist
        ]
        args += extraArguments
        return args
    }
}
#endif
