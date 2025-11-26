# match-code-signing Specification

## Purpose

Laner Match provides secure, Git-based code signing management for iOS development teams. It synchronizes certificates and provisioning profiles across team members, enabling consistent and reproducible code signing for development, distribution, and App Store builds.

Match addresses common iOS code signing challenges:
- Eliminates manual certificate and profile management
- Enables secure sharing across team members and CI/CD systems
- Provides version control for signing assets via encrypted Git storage
- Supports multiple certificate types and app identifiers
- Integrates with App Store Connect API for automated profile generation

## Architecture

```toon
components[7]{name,description}:
  MatchService,Orchestrates certificate/profile sync operations
  CryptoService,AES-256-GCM encryption/decryption of certificates
  GitStorage,Git repository operations for certificate storage
  KeychainService,macOS keychain management for certificate installation
  AppStoreConnectAPI,App Store Connect REST API integration
  JWTGenerator,JWT token generation for API authentication
  MatchConfiguration,Configuration from environment and options
```

## Requirements

### Requirement: Certificate Synchronization

The system SHALL synchronize code signing certificates and provisioning profiles from Git storage.

#### Scenario: Sync development certificates

- **GIVEN** Match configuration with valid Git URL and team ID
- **WHEN** sync is called with type: .development
- **THEN** downloads encrypted certificates from certs/development
- **AND** decrypts certificates with AES-256-GCM using MATCH_PASSWORD
- **AND** installs certificates to login keychain
- **AND** downloads provisioning profiles from profiles/development
- **AND** installs profiles to ~/Library/MobileDevice/Provisioning Profiles
- **AND** returns SyncResult with certificate and profile lists

#### Scenario: Sync distribution certificates

- **GIVEN** Match configuration
- **WHEN** sync is called with type: .distribution, .adhoc, or .appstore
- **THEN** downloads from certs/distribution
- **AND** downloads profiles from corresponding profile directory
- **AND** installs to system locations

#### Scenario: Sync for specific app identifier

- **GIVEN** Match configuration
- **WHEN** sync is called with appIdentifiers: ["com.example.app"]
- **THEN** filters profiles to only specified app identifier
- **AND** installs only matching profiles

#### Scenario: Sync in readonly mode

- **GIVEN** Match configuration with readonly: true
- **WHEN** sync is called and certificates are missing
- **THEN** throws MatchError.certificateNotFound
- **AND** does not create new certificates

#### Scenario: Sync with force for new devices

- **GIVEN** Match configuration with forceForNewDevices: true
- **AND** new devices have been registered
- **WHEN** sync is called
- **THEN** regenerates provisioning profiles with new device UDIDs
- **AND** commits updated profiles to Git

#### Scenario: Certificate already exists in keychain

- **GIVEN** certificate is already installed
- **WHEN** sync is called
- **THEN** skips duplicate installation
- **AND** logs "Certificate already installed"

### Requirement: Certificate Encryption

The system SHALL encrypt certificates using AES-256-GCM.

#### Scenario: Encrypt certificate

- **GIVEN** CryptoService with password
- **WHEN** encrypt is called with certificate data
- **THEN** generates random 128-bit salt
- **AND** derives key from password using HKDF-SHA256
- **AND** generates random 96-bit nonce
- **AND** encrypts data with AES-256-GCM
- **AND** returns result in format: [salt:16][nonce:12][ciphertext][tag:16]

#### Scenario: Decrypt certificate

- **GIVEN** CryptoService with password
- **WHEN** decrypt is called with encrypted data
- **THEN** extracts salt from first 16 bytes
- **AND** extracts nonce from bytes 16-27
- **AND** derives key from password using HKDF-SHA256
- **AND** decrypts ciphertext and verifies authentication tag
- **AND** returns plaintext certificate data

#### Scenario: Wrong password

- **GIVEN** CryptoService with incorrect password
- **WHEN** decrypt is called
- **THEN** throws CryptoError.decryptionFailed

#### Scenario: Corrupted data

- **GIVEN** CryptoService with corrupted encrypted data
- **WHEN** decrypt is called
- **THEN** throws CryptoError.invalidData

### Requirement: Git Storage

The system SHALL store certificates in Git repository with version control.

#### Scenario: Clone repository

- **GIVEN** GitStorage with Git URL
- **WHEN** clone is called
- **THEN** clones repository to temporary directory
- **AND** checks out specified branch
- **AND** returns local path

#### Scenario: Download certificate

- **GIVEN** GitStorage with cloned repository
- **WHEN** downloadCertificate is called with type
- **THEN** reads certificate from certs/{type} directory
- **AND** returns encrypted certificate data

#### Scenario: Upload certificate

- **GIVEN** GitStorage with cloned repository
- **WHEN** uploadCertificate is called with certificate data
- **THEN** writes encrypted data to certs/{type}/cert.p12
- **AND** stages file for commit

#### Scenario: Commit and push

- **GIVEN** GitStorage with staged changes
- **WHEN** commitAndPush is called
- **THEN** commits with message "Update certificates"
- **AND** pushes to remote repository
- **AND** cleans up temporary directory

#### Scenario: Git authentication with token

- **GIVEN** GitStorage with MATCH_GIT_BASIC_AUTHORIZATION environment variable
- **WHEN** clone is called
- **THEN** uses Basic authentication with provided token

#### Scenario: Custom Git branch

- **GIVEN** GitStorage with branch: "feature-branch"
- **WHEN** clone is called
- **THEN** checks out feature-branch

#### Scenario: Repository not found

- **GIVEN** GitStorage with invalid Git URL
- **WHEN** clone is called
- **THEN** throws GitStorageError.cloneFailed

### Requirement: Keychain Management

The system SHALL install certificates to macOS keychain.

#### Scenario: Install certificate

- **GIVEN** KeychainService with certificate data
- **WHEN** installCertificate is called
- **THEN** creates temporary .p12 file
- **AND** runs `security import` with login keychain
- **AND** sets access control for codesign and other tools
- **AND** deletes temporary file

#### Scenario: Certificate already installed

- **GIVEN** KeychainService with certificate already in keychain
- **WHEN** installCertificate is called
- **THEN** detects duplicate by certificate hash
- **AND** skips installation
- **AND** logs warning

#### Scenario: Install to custom keychain

- **GIVEN** KeychainService with custom keychain path
- **WHEN** installCertificate is called
- **THEN** imports to specified keychain

#### Scenario: Keychain locked

- **GIVEN** KeychainService with locked keychain
- **WHEN** installCertificate is called
- **THEN** throws KeychainError.keychainLocked

### Requirement: App Store Connect Integration

The system SHALL integrate with App Store Connect API for certificate and profile management.

#### Scenario: List certificates

- **GIVEN** AppStoreConnectAPI with valid credentials
- **WHEN** listCertificates is called with type: "IOS_DEVELOPMENT"
- **THEN** generates JWT token with ES256 algorithm
- **AND** makes GET request to /v1/certificates
- **AND** filters by certificateType
- **AND** returns array of Certificate objects

#### Scenario: Create certificate

- **GIVEN** AppStoreConnectAPI with valid credentials
- **WHEN** createCertificate is called with CSR
- **THEN** makes POST request to /v1/certificates
- **AND** uploads certificate signing request
- **AND** returns new Certificate with id and certificateContent

#### Scenario: Revoke certificate

- **GIVEN** AppStoreConnectAPI with certificate ID
- **WHEN** revokeCertificate is called
- **THEN** makes DELETE request to /v1/certificates/{id}
- **AND** certificate is revoked from Apple servers

#### Scenario: List provisioning profiles

- **GIVEN** AppStoreConnectAPI with team ID
- **WHEN** listProfiles is called with type: "IOS_APP_ADHOC"
- **THEN** makes GET request to /v1/profiles
- **AND** filters by profileType
- **AND** returns array of ProvisioningProfile objects

#### Scenario: Create provisioning profile

- **GIVEN** AppStoreConnectAPI with certificate IDs and device IDs
- **WHEN** createProfile is called
- **THEN** makes POST request to /v1/profiles
- **AND** associates certificate and devices
- **AND** returns new ProvisioningProfile with profile content

#### Scenario: Delete provisioning profile

- **GIVEN** AppStoreConnectAPI with profile ID
- **WHEN** deleteProfile is called
- **THEN** makes DELETE request to /v1/profiles/{id}

#### Scenario: Invalid API credentials

- **GIVEN** AppStoreConnectAPI with invalid key
- **WHEN** any API call is made
- **THEN** throws APIError.unauthorized with 401 status

#### Scenario: JWT token generation

- **GIVEN** JWTGenerator with API key, issuer ID, and key ID
- **WHEN** generate is called
- **THEN** creates JWT header with alg: ES256, kid: key_id
- **AND** creates JWT payload with iss: issuer_id, exp: current_time + 10min, aud: appstoreconnect-v1
- **AND** signs with ES256 using private key
- **AND** returns base64url-encoded token

### Requirement: Device Registration

The system SHALL register devices with App Store Connect.

#### Scenario: Register devices from file

- **GIVEN** devices file with format "Name\tUDID" per line
- **WHEN** registerDevices is called with file path
- **THEN** parses file line by line
- **AND** registers each device via App Store Connect API
- **AND** returns RegisterDevicesResult with registered and existing device lists

#### Scenario: Register devices from array

- **GIVEN** array of (name, udid) tuples
- **WHEN** registerDevices is called with array and platform
- **THEN** registers each device with specified platform
- **AND** returns result with registration status

#### Scenario: Device already registered

- **GIVEN** device UDID already exists in App Store Connect
- **WHEN** registerDevices is called
- **THEN** skips duplicate registration
- **AND** adds to existing devices list

#### Scenario: Register for specific platform

- **GIVEN** device with platform: .tvOS
- **WHEN** registerDevices is called
- **THEN** creates device with platformType: "TVOS"

#### Scenario: Invalid device file format

- **GIVEN** devices file with invalid format
- **WHEN** registerDevices is called
- **THEN** throws MatchError.invalidDeviceFile

### Requirement: Nuke Operation

The system SHALL provide destructive certificate revocation.

#### Scenario: Nuke development certificates

- **GIVEN** MatchService with valid configuration
- **WHEN** nuke is called with type: .development
- **THEN** lists all development certificates from App Store Connect
- **AND** revokes each certificate
- **AND** deletes all development provisioning profiles
- **AND** removes files from Git repository
- **AND** commits changes with message "Nuke development"
- **AND** returns NukeResult with counts

#### Scenario: Nuke with user confirmation

- **GIVEN** CLI command `laner match nuke --type distribution`
- **WHEN** user is prompted
- **THEN** displays warning about permanent revocation
- **AND** requires user to type "yes" to continue

#### Scenario: Nuke with force flag

- **GIVEN** CLI command `laner match nuke --type distribution --force`
- **WHEN** executed
- **THEN** skips confirmation prompt
- **AND** proceeds with revocation

### Requirement: Password Management

The system SHALL support password change operations.

#### Scenario: Change encryption password

- **GIVEN** MatchService with old password
- **WHEN** changePassword is called with new password
- **THEN** downloads all encrypted certificates
- **AND** decrypts with old password
- **AND** re-encrypts with new password
- **AND** uploads re-encrypted files to Git
- **AND** commits changes

#### Scenario: Wrong old password

- **GIVEN** MatchService with incorrect old password
- **WHEN** changePassword is called
- **THEN** throws CryptoError.decryptionFailed

### Requirement: Configuration Management

The system SHALL support flexible configuration from environment and options.

#### Scenario: Configuration from environment

- **GIVEN** environment variables:
  - MATCH_GIT_URL="https://github.com/org/certs.git"
  - MATCH_TEAM_ID="ABCD1234"
  - MATCH_PASSWORD="secret"
  - APP_STORE_CONNECT_API_KEY_ID="ABC123"
  - APP_STORE_CONNECT_API_ISSUER_ID="xyz"
  - APP_STORE_CONNECT_API_KEY_PATH="/path/to/key.p8"
- **WHEN** MatchConfiguration.fromEnvironment is called
- **THEN** creates configuration with all values from environment

#### Scenario: Missing required environment variable

- **GIVEN** MATCH_PASSWORD is not set
- **WHEN** MatchConfiguration.fromEnvironment is called
- **THEN** throws MatchError.missingEnvironmentVariable("MATCH_PASSWORD")

#### Scenario: Optional environment variables

- **GIVEN** MATCH_READONLY="true" and MATCH_FORCE_FOR_NEW_DEVICES="true"
- **WHEN** MatchConfiguration.fromEnvironment is called
- **THEN** sets readonly: true and forceForNewDevices: true

#### Scenario: Custom Git branch

- **GIVEN** MATCH_GIT_BRANCH="feature-branch"
- **WHEN** MatchConfiguration.fromEnvironment is called
- **THEN** sets branch to "feature-branch" instead of default "master"

#### Scenario: Git authentication token

- **GIVEN** MATCH_GIT_BASIC_AUTHORIZATION="token"
- **WHEN** GitStorage clones repository
- **THEN** uses Basic authentication with token

### Requirement: Certificate Types

The system SHALL support multiple certificate types.

#### Scenario: Certificate type storage paths

- **GIVEN** CertificateType enum
- **WHEN** querying storagePath
- **THEN** .development returns "certs/development"
- **AND** .distribution, .adhoc, .appstore return "certs/distribution"

#### Scenario: Certificate type profile paths

- **GIVEN** CertificateType enum
- **WHEN** querying profilePath
- **THEN** .development returns "profiles/development"
- **AND** .distribution returns "profiles/distribution"
- **AND** .adhoc returns "profiles/adhoc"
- **AND** .appstore returns "profiles/appstore"

#### Scenario: Apple certificate type mapping

- **GIVEN** CertificateType enum
- **WHEN** querying appleType
- **THEN** .development returns "IOS_DEVELOPMENT"
- **AND** .distribution, .adhoc, .appstore return "IOS_DISTRIBUTION"

#### Scenario: Apple profile type mapping

- **GIVEN** CertificateType enum
- **WHEN** querying profileType
- **THEN** .development returns "IOS_APP_DEVELOPMENT"
- **AND** .distribution, .appstore return "IOS_APP_STORE"
- **AND** .adhoc returns "IOS_APP_ADHOC"

### Requirement: Error Handling

The system SHALL provide comprehensive error handling.

#### Scenario: MatchError types

- **GIVEN** MatchError enum
- **THEN** provides cases: certificateNotFound, profileNotFound, invalidConfiguration, gitOperationFailed, keychainOperationFailed, apiError, encryptionFailed, missingEnvironmentVariable

#### Scenario: CryptoError types

- **GIVEN** CryptoError enum
- **THEN** provides cases: decryptionFailed, encryptionFailed, invalidData, invalidPassword

#### Scenario: GitStorageError types

- **GIVEN** GitStorageError enum
- **THEN** provides cases: cloneFailed, commitFailed, pushFailed, fileNotFound

#### Scenario: KeychainError types

- **GIVEN** KeychainError enum
- **THEN** provides cases: keychainLocked, importFailed, duplicateCertificate

#### Scenario: APIError types

- **GIVEN** APIError enum
- **THEN** provides cases: unauthorized, notFound, rateLimited, serverError, networkError

### Requirement: Platform Support

The system SHALL be macOS-only with graceful handling on other platforms.

#### Scenario: macOS execution

- **GIVEN** macOS system with Xcode
- **WHEN** Match commands are executed
- **THEN** all operations function correctly

#### Scenario: Linux execution

- **GIVEN** Linux system
- **WHEN** `laner match` is executed
- **THEN** displays error "The match command is only available on macOS"
- **AND** exits with code 1

#### Scenario: Conditional compilation

- **GIVEN** Match implementation
- **THEN** core functionality is wrapped in `#if os(macOS)`
- **AND** Linux stub provides appropriate error message

### Requirement: DSL Integration

The system SHALL integrate with Laner DSL for lane definitions.

#### Scenario: Match in lane

- **GIVEN** lane definition
- **WHEN** match() is called in LaneBuilder
- **THEN** creates MatchAction
- **AND** action executes during lane execution

#### Scenario: Complete signing workflow

```swift
lane("beta") {
    registerDevices(file: "devices.txt")
    match(
        type: .adhoc,
        appIdentifier: "com.example.app",
        forceForNewDevices: true
    )
    gym(scheme: "MyApp", exportMethod: .adHoc)
}
```

- **GIVEN** lane with register, match, and gym actions
- **WHEN** lane executes
- **THEN** devices are registered first
- **AND** match syncs certificates with new devices
- **AND** gym builds with correct signing

#### Scenario: Multiple certificate types

```swift
lane("sign_all") {
    match(type: .development)
    match(type: .appstore)
    match(type: .adhoc)
}
```

- **GIVEN** lane with multiple match calls
- **WHEN** lane executes
- **THEN** each certificate type is synced in order

### Requirement: Command Line Interface

The system SHALL provide intuitive CLI commands.

#### Scenario: CLI subcommands

- **GIVEN** `laner match` command
- **THEN** provides subcommands: sync, init, nuke, register, change-password

#### Scenario: Sync command options

- **GIVEN** `laner match sync` command
- **THEN** requires --type option
- **AND** supports optional flags: --readonly, --app-identifier, --git-url, --team-id, --branch

#### Scenario: Init command options

- **GIVEN** `laner match init` command
- **THEN** requires --git-url and --team-id options
- **AND** supports optional --branch and --skip-setup flags

#### Scenario: Nuke command options

- **GIVEN** `laner match nuke` command
- **THEN** requires --type option
- **AND** supports optional --force flag for skipping confirmation

#### Scenario: Register command options

- **GIVEN** `laner match register` command
- **THEN** requires --devices-file option
- **AND** supports optional --platform flag (defaults to iOS)

#### Scenario: Change password command options

- **GIVEN** `laner match change-password` command
- **THEN** supports --new-password option
- **AND** reads old password from MATCH_PASSWORD environment

### Requirement: Environment Variables

The system SHALL support environment variable configuration.

```toon
environment_variables[11]{name,description,required}:
  MATCH_PASSWORD,Encryption password for certificates,yes
  MATCH_GIT_URL,Git repository URL for certificate storage,yes
  MATCH_TEAM_ID,Apple Developer Team ID,yes
  MATCH_GIT_BRANCH,Git branch to use (default: master),no
  MATCH_READONLY,Don't create new certificates if missing,no
  MATCH_FORCE_FOR_NEW_DEVICES,Regenerate profiles when devices change,no
  MATCH_GIT_BASIC_AUTHORIZATION,Git authentication token,no
  APP_STORE_CONNECT_API_KEY_ID,App Store Connect API key identifier,conditional
  APP_STORE_CONNECT_API_ISSUER_ID,App Store Connect API issuer ID,conditional
  APP_STORE_CONNECT_API_KEY_PATH,Path to .p8 private key file,conditional
  MATCH_NEW_PASSWORD,New password for change-password command,no
```

Note: App Store Connect API credentials are required for operations that need API access (create certificates, register devices, etc.).

### Requirement: Security

The system SHALL implement secure certificate handling.

#### Scenario: Encryption at rest

- **GIVEN** certificates stored in Git
- **THEN** all certificate files are encrypted with AES-256-GCM
- **AND** encryption keys are never stored in Git

#### Scenario: Secure password handling

- **GIVEN** Match operations
- **THEN** passwords are read from environment variables
- **AND** passwords are never logged or displayed
- **AND** passwords are cleared from memory after use

#### Scenario: Keychain access control

- **GIVEN** certificates installed to keychain
- **THEN** access control is set for codesign and related tools
- **AND** other applications cannot access private keys

#### Scenario: Git authentication

- **GIVEN** Git operations with private repository
- **THEN** supports Basic authentication with token
- **AND** credentials are passed securely via environment

#### Scenario: Temporary file cleanup

- **GIVEN** Match operations create temporary files
- **WHEN** operation completes or fails
- **THEN** all temporary files are deleted
- **AND** no certificate data remains on disk

### Requirement: Concurrency

The system SHALL support concurrent execution safely.

#### Scenario: Actor-based services

- **GIVEN** MatchService, CryptoService, GitStorage, KeychainService
- **THEN** each service is implemented as an actor
- **AND** internal state is protected from data races

#### Scenario: Sendable types

- **GIVEN** configuration and model types
- **THEN** all types conform to Sendable
- **AND** can be safely shared across concurrency domains

#### Scenario: Async operations

- **GIVEN** Match operations
- **THEN** all I/O operations use async/await
- **AND** operations can be cancelled via Task cancellation

### Requirement: Testing

The system SHALL support comprehensive testing.

#### Scenario: Unit tests for crypto

- **GIVEN** CryptoService tests
- **WHEN** encryption and decryption are tested
- **THEN** verifies roundtrip correctness
- **AND** verifies error handling for wrong password

#### Scenario: Unit tests for Git storage

- **GIVEN** GitStorage tests
- **WHEN** Git operations are tested
- **THEN** uses mock Git repository
- **AND** verifies file operations

#### Scenario: Integration tests for Match service

- **GIVEN** MatchService tests
- **WHEN** sync operation is tested
- **THEN** uses test fixtures for certificates
- **AND** verifies end-to-end flow

#### Scenario: Mock App Store Connect API

- **GIVEN** AppStoreConnectAPI tests
- **WHEN** API calls are tested
- **THEN** uses URLProtocol mocking
- **AND** verifies request formation and response parsing
