#if os(macOS)
import Testing
import Foundation
@testable import SwiftlaneKit

@Suite("Xcodebuild Tests")
struct XcodebuildTests {
    @Suite("BuildOptions Tests")
    struct BuildOptionsTests {
        @Test("toArguments with project")
        func toArgumentsWithProject() {
            let options = BuildOptions(
                project: "MyApp.xcodeproj",
                scheme: "MyApp",
                configuration: "Release"
            )
            let args = options.toArguments()

            #expect(args.contains("-project"))
            #expect(args.contains("MyApp.xcodeproj"))
            #expect(args.contains("-scheme"))
            #expect(args.contains("MyApp"))
            #expect(args.contains("-configuration"))
            #expect(args.contains("Release"))
            #expect(args.contains("build"))
        }

        @Test("toArguments with workspace")
        func toArgumentsWithWorkspace() {
            let options = BuildOptions(
                workspace: "MyApp.xcworkspace",
                scheme: "MyApp"
            )
            let args = options.toArguments()

            #expect(args.contains("-workspace"))
            #expect(args.contains("MyApp.xcworkspace"))
            #expect(!args.contains("-project"))
        }

        @Test("toArguments with clean")
        func toArgumentsWithClean() {
            let options = BuildOptions(
                project: "MyApp.xcodeproj",
                clean: true
            )
            let args = options.toArguments()

            #expect(args.contains("clean"))
            #expect(args.contains("build"))
        }

        @Test("toArguments with buildForTesting")
        func toArgumentsWithBuildForTesting() {
            let options = BuildOptions(
                project: "MyApp.xcodeproj",
                buildForTesting: true
            )
            let args = options.toArguments()

            #expect(args.contains("build-for-testing"))
            #expect(!args.contains("build"))
        }
    }

    @Suite("TestOptions Tests")
    struct TestOptionsTests {
        @Test("toArguments with basic options")
        func toArgumentsBasic() {
            let options = TestOptions(
                project: "MyApp.xcodeproj",
                scheme: "MyAppTests",
                destination: "platform=iOS Simulator,name=iPhone 15"
            )
            let args = options.toArguments()

            #expect(args.contains("-project"))
            #expect(args.contains("-scheme"))
            #expect(args.contains("-destination"))
            #expect(args.contains("test"))
        }

        @Test("toArguments with onlyTesting")
        func toArgumentsWithOnlyTesting() {
            let options = TestOptions(
                project: "MyApp.xcodeproj",
                scheme: "MyAppTests",
                onlyTesting: ["MyAppTests/testExample", "MyAppTests/testOther"]
            )
            let args = options.toArguments()

            let onlyTestingCount = args.filter { $0 == "-only-testing" }.count
            #expect(onlyTestingCount == 2)
        }

        @Test("toArguments with testWithoutBuilding")
        func toArgumentsWithTestWithoutBuilding() {
            let options = TestOptions(
                project: "MyApp.xcodeproj",
                testWithoutBuilding: true
            )
            let args = options.toArguments()

            #expect(args.contains("test-without-building"))
            #expect(!args.contains("test") || args.last == "test-without-building")
        }
    }

    @Suite("ArchiveOptions Tests")
    struct ArchiveOptionsTests {
        @Test("toArguments produces correct output")
        func toArguments() {
            let options = ArchiveOptions(
                project: "MyApp.xcodeproj",
                scheme: "MyApp",
                configuration: "Release",
                archivePath: "build/MyApp.xcarchive"
            )
            let args = options.toArguments()

            #expect(args.contains("-archivePath"))
            #expect(args.contains("build/MyApp.xcarchive"))
            #expect(args.contains("archive"))
        }
    }

    @Suite("ExportOptions Tests")
    struct ExportOptionsTests {
        @Test("toArguments produces correct output")
        func toArguments() {
            let options = ExportOptions(
                archivePath: "build/MyApp.xcarchive",
                exportPath: "build/export",
                exportOptionsPlist: "ExportOptions.plist"
            )
            let args = options.toArguments()

            #expect(args.contains("-exportArchive"))
            #expect(args.contains("-archivePath"))
            #expect(args.contains("-exportPath"))
            #expect(args.contains("-exportOptionsPlist"))
        }
    }

    @Suite("Result Tests")
    struct ResultTests {
        @Test("BuildResult stores values correctly")
        func buildResultStoresValues() {
            let result = BuildResult(
                succeeded: true,
                output: "Build succeeded",
                duration: .seconds(10),
                warnings: ["warning 1"],
                errors: []
            )

            #expect(result.succeeded)
            #expect(result.warnings.count == 1)
            #expect(result.errors.isEmpty)
        }

        @Test("TestResult calculates totalTests")
        func testResultCalculatesTotalTests() {
            let result = TestResult(
                succeeded: false,
                output: "Tests failed",
                duration: .seconds(5),
                testsPassed: 8,
                testsFailed: 2,
                testsSkipped: 1
            )

            #expect(result.totalTests == 11)
            #expect(!result.succeeded)
        }
    }
}
#endif
