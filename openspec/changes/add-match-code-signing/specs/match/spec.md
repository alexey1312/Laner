## ADDED Requirements

### Requirement: Match Sync Operation

The system SHALL provide a `match sync` operation to synchronize code signing credentials from Git storage to the local machine.

#### Scenario: Sync development certificates

- **GIVEN** a Git repository with encrypted development certificates
- **AND** valid `MATCH_PASSWORD` environment variable
- **WHEN** user runs `match(type: .development)`
- **THEN** certificates are cloned from Git
- **AND** decrypted using AES-256-GCM
- **AND** installed to macOS Keychain
- **AND** provisioning profiles copied to `~/Library/MobileDevice/Provisioning Profiles/`

#### Scenario: Sync appstore certificates

- **GIVEN** a Git repository with encrypted distribution certificates
- **WHEN** user runs `match(type: .appstore)`
- **THEN** distribution certificate is installed
- **AND** App Store provisioning profile is installed

#### Scenario: Sync adhoc certificates

- **GIVEN** a Git repository with encrypted distribution certificates
- **WHEN** user runs `match(type: .adhoc)`
- **THEN** distribution certificate is installed
- **AND** Ad Hoc provisioning profile is installed

#### Scenario: Create missing certificates

- **GIVEN** no certificates exist in Git storage
- **AND** `readonly` is false
- **WHEN** user runs `match(type: .development)`
- **THEN** new certificate is created via App Store Connect API
- **AND** encrypted and pushed to Git repository

#### Scenario: Readonly mode prevents creation

- **GIVEN** no certificates exist in Git storage
- **AND** `readonly` is true
- **WHEN** user runs `match(type: .development, readonly: true)`
- **THEN** error "No certificates found in readonly mode" is thrown
- **AND** Git repository is not modified

#### Scenario: Invalid password

- **GIVEN** encrypted certificates in Git storage
- **AND** invalid `MATCH_PASSWORD`
- **WHEN** user runs `match(type: .development)`
- **THEN** error "Failed to decrypt certificates" is thrown

### Requirement: Match Nuke Operation

The system SHALL provide a `match nuke` operation to revoke and remove all certificates of a type.

#### Scenario: Nuke development certificates

- **GIVEN** development certificates in Git storage and Apple Developer Portal
- **WHEN** user runs `swiftlane match nuke --type development`
- **THEN** user is prompted for confirmation
- **AND** certificates are revoked via App Store Connect API
- **AND** certificates removed from Git storage
- **AND** Git commit is pushed

#### Scenario: Nuke distribution certificates

- **GIVEN** distribution certificates in Git storage
- **WHEN** user runs `swiftlane match nuke --type distribution`
- **THEN** all distribution certificates are revoked
- **AND** associated provisioning profiles are deleted
- **AND** warning about App Store/TestFlight impact is shown

#### Scenario: Nuke confirmation required

- **GIVEN** user runs `swiftlane match nuke --type development`
- **WHEN** user does not confirm
- **THEN** operation is aborted
- **AND** no changes are made

### Requirement: Device Registration

The system SHALL provide device registration functionality via App Store Connect API.

#### Scenario: Register single device

- **GIVEN** valid App Store Connect API credentials
- **WHEN** user runs `registerDevices(name: "iPhone 15", udid: "00001111-...")`
- **THEN** device is registered via App Store Connect API
- **AND** success message includes device name

#### Scenario: Register devices from file

- **GIVEN** a file `devices.txt` with device names and UDIDs
- **WHEN** user runs `registerDevices(file: "devices.txt")`
- **THEN** all devices are registered
- **AND** count of registered devices is reported

#### Scenario: Force profile regeneration for new devices

- **GIVEN** new devices registered since last profile generation
- **WHEN** user runs `match(type: .adhoc, forceForNewDevices: true)`
- **THEN** Ad Hoc profiles are regenerated with new devices
- **AND** updated profiles are pushed to Git

### Requirement: Encryption Service

The system SHALL encrypt/decrypt files using AES-256-GCM compatible with Fastlane Match.

#### Scenario: Decrypt Fastlane Match file

- **GIVEN** a file encrypted by Fastlane Match
- **AND** correct password
- **WHEN** CryptoService.decrypt is called
- **THEN** file is successfully decrypted

#### Scenario: Encrypt for Fastlane Match compatibility

- **GIVEN** a certificate file
- **AND** encryption password
- **WHEN** CryptoService.encrypt is called
- **THEN** output is decryptable by Fastlane Match

#### Scenario: Wrong password detection

- **GIVEN** an encrypted file
- **AND** incorrect password
- **WHEN** CryptoService.decrypt is called
- **THEN** error is thrown indicating authentication failure

### Requirement: Git Storage Provider

The system SHALL support Git repositories for storing encrypted certificates.

#### Scenario: Clone repository

- **GIVEN** a Git URL with certificates
- **WHEN** GitStorage.download is called
- **THEN** repository is cloned to temporary directory
- **AND** shallow clone is used for efficiency

#### Scenario: Push changes

- **GIVEN** modified certificate files
- **WHEN** GitStorage.upload is called
- **THEN** files are committed with descriptive message
- **AND** pushed to remote repository

#### Scenario: SSH authentication

- **GIVEN** Git URL with SSH (`git@github.com:...`)
- **AND** SSH key available
- **WHEN** GitStorage.download is called
- **THEN** SSH key is used for authentication

#### Scenario: Token authentication

- **GIVEN** Git URL with HTTPS
- **AND** `MATCH_GIT_BASIC_AUTHORIZATION` set (base64 encoded)
- **WHEN** GitStorage.download is called
- **THEN** basic auth header is used

### Requirement: Keychain Service

The system SHALL install certificates to macOS Keychain.

#### Scenario: Install to login keychain

- **GIVEN** a decrypted certificate (.p12 file)
- **AND** running locally (not CI)
- **WHEN** KeychainService.install is called
- **THEN** certificate is installed to login keychain
- **AND** keychain is unlocked if needed

#### Scenario: Create temporary keychain for CI

- **GIVEN** running in CI environment
- **WHEN** KeychainService.createTemporaryKeychain is called
- **THEN** new keychain is created with random password
- **AND** keychain is added to search list

#### Scenario: Install provisioning profile

- **GIVEN** a decrypted provisioning profile
- **WHEN** KeychainService.installProfile is called
- **THEN** profile is copied to `~/Library/MobileDevice/Provisioning Profiles/`
- **AND** file UUID matches profile UUID

#### Scenario: Linux platform error

- **GIVEN** running on Linux
- **WHEN** KeychainService.install is called
- **THEN** error "Keychain operations require macOS" is thrown

### Requirement: App Store Connect API Client

The system SHALL interact with App Store Connect API for certificate management.

#### Scenario: JWT authentication

- **GIVEN** API key (.p8 file), key ID, and issuer ID
- **WHEN** API request is made
- **THEN** JWT token is generated with ES256 signature
- **AND** token is used in Authorization header

#### Scenario: List certificates

- **GIVEN** valid API credentials
- **WHEN** AppStoreConnectAPI.listCertificates is called
- **THEN** all certificates are returned with types and expiry dates

#### Scenario: Create certificate

- **GIVEN** a CSR (Certificate Signing Request)
- **AND** certificate type (development/distribution)
- **WHEN** AppStoreConnectAPI.createCertificate is called
- **THEN** certificate is created in Developer Portal
- **AND** certificate content is returned

#### Scenario: Revoke certificate

- **GIVEN** certificate ID
- **WHEN** AppStoreConnectAPI.revokeCertificate is called
- **THEN** certificate is revoked in Developer Portal

#### Scenario: Create provisioning profile

- **GIVEN** app identifier, certificate ID, and device IDs
- **WHEN** AppStoreConnectAPI.createProfile is called
- **THEN** profile is created with specified parameters
- **AND** profile content is returned

### Requirement: Match CLI Commands

The system SHALL provide CLI commands for Match operations.

#### Scenario: Match init command

- **GIVEN** no match configuration exists
- **WHEN** user runs `swiftlane match init`
- **THEN** prompts for Git URL
- **AND** prompts for team ID
- **AND** creates `Swiftlane/MatchConfig.swift`

#### Scenario: Match sync command

- **GIVEN** valid match configuration
- **WHEN** user runs `swiftlane match sync --type appstore`
- **THEN** certificates are downloaded and installed
- **AND** success message shows installed credentials

#### Scenario: Match nuke command

- **GIVEN** valid match configuration
- **WHEN** user runs `swiftlane match nuke --type development`
- **THEN** confirmation is requested
- **AND** certificates are revoked on confirmation

#### Scenario: Match register command

- **GIVEN** valid match configuration
- **WHEN** user runs `swiftlane match register --name "iPhone" --udid "00001111..."`
- **THEN** device is registered via API
- **AND** success message is shown

#### Scenario: Match change-password command

- **GIVEN** existing encrypted repository
- **WHEN** user runs `swiftlane match change-password`
- **THEN** prompts for old password
- **AND** prompts for new password
- **AND** re-encrypts all files
- **AND** pushes to repository

### Requirement: Match DSL Action

The system SHALL provide `match()` DSL function for lane usage.

#### Scenario: Match action in lane

- **GIVEN** a lane with `match(type: .appstore)`
- **WHEN** lane is executed
- **THEN** MatchService.sync is called with type appstore
- **AND** action reports installed credentials

#### Scenario: Match action with options

- **GIVEN** a lane with `match(type: .development, readonly: true, appIdentifier: "com.app")`
- **WHEN** lane is executed
- **THEN** only specified app's profiles are synced
- **AND** no new certificates are created

#### Scenario: Match action failure handling

- **GIVEN** a lane with `match(type: .appstore)`
- **AND** Git repository is unreachable
- **WHEN** lane is executed
- **THEN** error is propagated to lane
- **AND** subsequent actions are not executed
