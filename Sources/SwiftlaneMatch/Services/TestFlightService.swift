import Foundation
import Logging

/// Actor responsible for TestFlight operations.
///
/// Orchestrates upload, processing, and distribution of builds to TestFlight.
public actor TestFlightService {
    /// Default polling interval for processing checks (30 seconds).
    public static let defaultPollingInterval: TimeInterval = 30

    /// Default timeout for processing (30 minutes).
    public static let defaultProcessingTimeout: TimeInterval = 30 * 60

    private let api: AppStoreConnectAPI
    private let uploader: ChunkedUploader
    private let logger: Logger
    private let pollingInterval: TimeInterval
    private let processingTimeout: TimeInterval

    /// Initializes a new TestFlightService.
    /// - Parameters:
    ///   - api: The App Store Connect API client.
    ///   - pollingInterval: Interval between processing status checks (default: 30s).
    ///   - processingTimeout: Maximum time to wait for processing (default: 30 min).
    public init(
        api: AppStoreConnectAPI,
        pollingInterval: TimeInterval = TestFlightService.defaultPollingInterval,
        processingTimeout: TimeInterval = TestFlightService.defaultProcessingTimeout
    ) {
        self.api = api
        self.uploader = ChunkedUploader(api: api)
        self.logger = Logger(label: "com.swiftlane.match.testflight")
        self.pollingInterval = pollingInterval
        self.processingTimeout = processingTimeout
    }

    /// Shuts down the service and releases resources.
    public func shutdown() async throws {
        try await uploader.shutdown()
    }

    /// Uploads an IPA file to TestFlight.
    /// - Parameters:
    ///   - ipaPath: Path to the IPA file.
    ///   - appId: The App Store Connect app ID.
    ///   - progress: Callback for progress updates.
    /// - Returns: The build upload ID.
    public func upload(
        ipaPath: String,
        appId: String,
        progress: @escaping @Sendable (UploadProgress) -> Void
    ) async throws -> String {
        logger.info("Starting TestFlight upload")
        logger.info("  IPA: \(ipaPath)")
        logger.info("  App ID: \(appId)")

        return try await uploader.upload(
            ipaPath: ipaPath,
            appId: appId,
            progress: progress
        )
    }

    /// Waits for a build to finish processing.
    /// - Parameter buildId: The build ID to wait for.
    /// - Returns: The processed build.
    /// - Throws: `TestFlightError.processingTimeout` if the build doesn't finish in time.
    public func waitForProcessing(buildId: String) async throws -> Build {
        logger.info("Waiting for build \(buildId) to process")

        let startTime = Date()

        while true {
            let build = try await api.getBuild(id: buildId)

            switch build.processingState {
            case .valid:
                logger.info("Build processing completed successfully")
                return build

            case .invalid, .failed:
                throw TestFlightError.processingFailed(
                    "Build processing failed with state: \(build.processingState.rawValue)"
                )

            case .processing, .unknown:
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > processingTimeout {
                    throw TestFlightError.processingTimeout
                }

                logger.debug("Build still processing, waiting \(Int(pollingInterval))s...")
                try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
            }
        }
    }

    /// Distributes a build to TestFlight beta groups.
    /// - Parameters:
    ///   - buildId: The build ID to distribute.
    ///   - groups: Names of beta groups to add the build to.
    ///   - whatsNew: Optional release notes for testers.
    ///   - appId: The app ID (required to look up groups).
    public func distribute(
        buildId: String,
        groups: [String],
        whatsNew: String?,
        appId: String
    ) async throws {
        logger.info("Distributing build \(buildId) to TestFlight")

        // Set what's new if provided
        if let whatsNew = whatsNew, !whatsNew.isEmpty {
            logger.info("Setting release notes")
            try await api.setBetaTestInfo(buildId: buildId, whatsNew: whatsNew)
        }

        // Get available beta groups
        let availableGroups = try await api.listBetaGroups(appId: appId)

        // Add build to each requested group
        for groupName in groups {
            guard let group = availableGroups.first(where: { $0.name.lowercased() == groupName.lowercased() }) else {
                throw TestFlightError.groupNotFound(groupName)
            }

            logger.info("Adding build to group: \(group.name)")
            try await api.addBuildToBetaGroup(buildId: buildId, groupId: group.id)
        }

        logger.info("Build distributed successfully to \(groups.count) group(s)")
    }

    /// Finds a beta group by name.
    /// - Parameters:
    ///   - appId: The app ID.
    ///   - name: The group name to find.
    /// - Returns: The matching beta group.
    /// - Throws: `TestFlightError.groupNotFound` if the group doesn't exist.
    public func findGroupByName(appId: String, name: String) async throws -> BetaGroup {
        let groups = try await api.listBetaGroups(appId: appId)

        guard let group = groups.first(where: { $0.name.lowercased() == name.lowercased() }) else {
            throw TestFlightError.groupNotFound(name)
        }

        return group
    }

    /// Gets the most recent build for an app.
    /// - Parameter appId: The app ID.
    /// - Returns: The most recent build, or nil if no builds exist.
    public func getMostRecentBuild(appId: String) async throws -> Build? {
        let builds = try await api.listBuilds(appId: appId, limit: 1)
        return builds.first
    }

    /// Lists recent builds for an app.
    /// - Parameters:
    ///   - appId: The app ID.
    ///   - limit: Maximum number of builds to return.
    /// - Returns: Array of recent builds.
    public func listRecentBuilds(appId: String, limit: Int = 10) async throws -> [Build] {
        return try await api.listBuilds(appId: appId, limit: limit)
    }

    /// Performs a complete upload and distribute operation.
    /// - Parameters:
    ///   - ipaPath: Path to the IPA file.
    ///   - appId: The App Store Connect app ID.
    ///   - groups: Names of beta groups to add the build to (optional).
    ///   - whatsNew: Release notes for testers (optional).
    ///   - skipWaitingForProcessing: If true, returns immediately after upload without waiting.
    ///   - progress: Callback for progress updates.
    /// - Returns: The uploaded build (may still be processing if skipWaitingForProcessing is true).
    public func uploadAndDistribute(
        ipaPath: String,
        appId: String,
        groups: [String]?,
        whatsNew: String?,
        skipWaitingForProcessing: Bool,
        progress: @escaping @Sendable (UploadProgress) -> Void
    ) async throws -> Build {
        // Upload the IPA
        _ = try await upload(ipaPath: ipaPath, appId: appId, progress: progress)

        // Get the most recent build (should be the one we just uploaded)
        guard let build = try await getMostRecentBuild(appId: appId) else {
            throw TestFlightError.apiError("Could not find uploaded build")
        }

        logger.info("Uploaded build version: \(build.version)")

        // Wait for processing if requested
        let processedBuild: Build
        if skipWaitingForProcessing {
            logger.info("Skipping processing wait as requested")
            processedBuild = build
        } else {
            processedBuild = try await waitForProcessing(buildId: build.id)
        }

        // Distribute to groups if specified
        if let groups = groups, !groups.isEmpty {
            try await distribute(
                buildId: processedBuild.id,
                groups: groups,
                whatsNew: whatsNew,
                appId: appId
            )
        } else if let whatsNew = whatsNew, !whatsNew.isEmpty {
            // Set what's new even without groups
            try await api.setBetaTestInfo(buildId: processedBuild.id, whatsNew: whatsNew)
        }

        return processedBuild
    }
}
