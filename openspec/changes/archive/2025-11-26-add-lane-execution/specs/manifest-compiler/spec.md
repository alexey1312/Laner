# Spec: manifest-compiler

Swift manifest compilation system for Swiftlanefile.swift.

## ADDED Requirements

### Requirement: Manifest Discovery

The system SHALL discover Swiftlanefile.swift in project directory.

#### Scenario: Find manifest in Swiftlane directory

- **GIVEN** a project with `Swiftlane/Swiftlanefile.swift`
- **WHEN** ManifestLoader.findManifestPath() is called
- **THEN** the path to Swiftlanefile.swift is returned

#### Scenario: No manifest found

- **GIVEN** a project without Swiftlane directory
- **WHEN** ManifestLoader.findManifestPath() is called
- **THEN** ManifestError.notFound is thrown
- **AND** error message suggests running `swiftlane init`

#### Scenario: Custom manifest path

- **GIVEN** a --manifest option with path "/custom/Swiftlanefile.swift"
- **WHEN** ManifestLoader is initialized with custom path
- **THEN** the specified file is used
- **AND** default discovery is skipped

### Requirement: Manifest Compilation

The system SHALL compile Swift manifests to executables.

#### Scenario: Compile valid manifest

- **GIVEN** a valid Swiftlanefile.swift importing SwiftlaneDSL
- **WHEN** ManifestCompiler.compile() is called
- **THEN** a temporary Swift package is generated
- **AND** `swift build` compiles the manifest
- **AND** compiled executable is returned

#### Scenario: Compilation with helpers

- **GIVEN** a Swiftlanefile.swift and SwiftlaneHelpers/ directory
- **WHEN** ManifestCompiler.compile() is called
- **THEN** helper files are included in compilation
- **AND** imports from SwiftlaneHelpers work

#### Scenario: Compilation error

- **GIVEN** a Swiftlanefile.swift with syntax errors
- **WHEN** ManifestCompiler.compile() is called
- **THEN** ManifestError.compilationFailed is thrown
- **AND** Swift compiler errors are included in message
- **AND** file:line references are preserved

#### Scenario: Missing Swift toolchain

- **GIVEN** Swift is not installed on the system
- **WHEN** ManifestCompiler.compile() is called
- **THEN** ManifestError.swiftNotFound is thrown
- **AND** error suggests installing Xcode or Swift toolchain

### Requirement: Manifest Execution

The system SHALL execute compiled manifests to extract configuration.

#### Scenario: Execute and parse JSON

- **GIVEN** a compiled manifest executable
- **WHEN** ManifestLoader executes it
- **THEN** JSON output is captured from stdout
- **AND** JSON is parsed to Swiftlanefile struct

#### Scenario: Execution failure

- **GIVEN** a compiled manifest that crashes at runtime
- **WHEN** ManifestLoader executes it
- **THEN** ManifestError.executionFailed is thrown
- **AND** stderr output is included in error

#### Scenario: Invalid JSON output

- **GIVEN** a manifest that outputs invalid JSON
- **WHEN** ManifestLoader parses output
- **THEN** ManifestError.invalidOutput is thrown

### Requirement: Manifest Caching

The system SHALL cache compiled manifests for performance.

#### Scenario: Cache hit

- **GIVEN** a previously compiled manifest with unchanged sources
- **WHEN** ManifestLoader.load() is called
- **THEN** cached executable is used
- **AND** compilation is skipped

#### Scenario: Cache invalidation on source change

- **GIVEN** a cached manifest
- **WHEN** Swiftlanefile.swift is modified
- **THEN** cache is invalidated on next load
- **AND** manifest is recompiled

#### Scenario: Cache invalidation on helper change

- **GIVEN** a cached manifest with helpers
- **WHEN** any file in SwiftlaneHelpers/ is modified
- **THEN** cache is invalidated
- **AND** manifest is recompiled

#### Scenario: Cache directory structure

- **GIVEN** ManifestCache is initialized
- **THEN** cache is stored in `~/.swiftlane/cache/`
- **AND** each project has unique cache directory (by path hash)

### Requirement: Generated Package Structure

The system MUST generate valid Swift package for compilation.

#### Scenario: Package.swift generation

- **GIVEN** a Swiftlanefile.swift to compile
- **WHEN** ManifestCompiler generates Package.swift
- **THEN** package depends on SwiftlaneDSL
- **AND** executable target includes manifest source
- **AND** macOS 13+ platform is specified

#### Scenario: Main entry point generation

- **GIVEN** a Swiftlanefile.swift with `let swiftlane = Swiftlanefile(...)`
- **WHEN** ManifestCompiler generates main.swift wrapper
- **THEN** wrapper imports SwiftlaneDSL and Foundation
- **AND** wrapper encodes swiftlane to JSON
- **AND** wrapper prints JSON to stdout
