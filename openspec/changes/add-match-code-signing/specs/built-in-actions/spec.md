## ADDED Requirements

### Requirement: MatchAction for Code Signing

The system SHALL provide MatchAction wrapping MatchService.sync for certificate synchronization.

#### Scenario: Sync with type

- **GIVEN** a MatchAction with type `.appstore`
- **WHEN** the action executes
- **THEN** MatchService.sync is called with appstore type
- **AND** certificates are installed to Keychain
- **AND** result contains installed certificate info

#### Scenario: Sync with app identifier

- **GIVEN** a MatchAction with appIdentifier "com.example.app"
- **WHEN** the action executes
- **THEN** only profiles for specified app are synced
- **AND** other app profiles are not touched

#### Scenario: Readonly mode

- **GIVEN** a MatchAction with readonly: true
- **WHEN** the action executes
- **AND** certificates are missing
- **THEN** error is thrown
- **AND** no certificates are created

#### Scenario: Force for new devices

- **GIVEN** a MatchAction with forceForNewDevices: true
- **AND** new devices registered since last sync
- **WHEN** the action executes
- **THEN** provisioning profiles are regenerated
- **AND** new devices are included

#### Scenario: Action failure handling

- **GIVEN** a MatchAction that cannot connect to Git
- **WHEN** the action executes
- **THEN** error is propagated
- **AND** lane execution stops

### Requirement: RegisterDevicesAction for Device Registration

The system SHALL provide RegisterDevicesAction for registering devices via App Store Connect API.

#### Scenario: Register from file

- **GIVEN** a RegisterDevicesAction with file "devices.txt"
- **WHEN** the action executes
- **THEN** devices are registered via API
- **AND** result contains registration count

#### Scenario: Register single device

- **GIVEN** a RegisterDevicesAction with name and UDID
- **WHEN** the action executes
- **THEN** device is registered
- **AND** result contains device name

#### Scenario: Duplicate device handling

- **GIVEN** a device already registered
- **WHEN** RegisterDevicesAction tries to register same UDID
- **THEN** no error is thrown
- **AND** existing device is returned

### Requirement: MatchOptions Structure

The system MUST provide typed MatchOptions struct for MatchAction.

#### Scenario: MatchOptions properties

- **GIVEN** MatchOptions struct
- **THEN** it has properties: type, readonly, appIdentifier, teamId, gitUrl, forceForNewDevices
- **AND** type is required (CertificateType enum)
- **AND** other properties are optional

### Requirement: RegisterDevicesOptions Structure

The system MUST provide typed RegisterDevicesOptions struct.

#### Scenario: RegisterDevicesOptions properties

- **GIVEN** RegisterDevicesOptions struct
- **THEN** it has properties: file, devices (hash map), platform
- **AND** either file or devices must be provided
- **AND** platform defaults to iOS

### Requirement: DSL Functions for Match

The system SHALL provide DSL convenience functions for match operations.

#### Scenario: match() function

- **GIVEN** DSL function `match(type:readonly:appIdentifier:)`
- **WHEN** called in lane context
- **THEN** creates and returns MatchAction with options

#### Scenario: registerDevices() function

- **GIVEN** DSL function `registerDevices(file:)` or `registerDevices(devices:)`
- **WHEN** called in lane context
- **THEN** creates and returns RegisterDevicesAction
