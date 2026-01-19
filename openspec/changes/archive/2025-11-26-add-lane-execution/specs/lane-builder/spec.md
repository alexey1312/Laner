# Spec: lane-builder

Result builder DSL for declarative lane definitions.

## ADDED Requirements

### Requirement: LaneBuilder Result Builder

The system SHALL provide a LaneBuilder result builder for declarative lane syntax.

#### Scenario: Define lane with multiple actions

- **GIVEN** a LaneBuilder result builder is available
- **WHEN** a developer writes:

```swift
Lane("build") {
    GymAction(scheme: "App")
    ScanAction(scheme: "AppTests")
}
```

- **THEN** the lane contains two actions in order
- **AND** both actions are wrapped as AnyAction

#### Scenario: Conditional action in lane

- **GIVEN** a LaneBuilder with conditional support
- **WHEN** a developer writes:

```swift
Lane("deploy") {
    GymAction(scheme: "App")
    if isProduction {
        UploadAction(destination: .appStore)
    }
}
```

- **THEN** the conditional action is included when condition is true
- **AND** the conditional action is omitted when condition is false

#### Scenario: Empty lane

- **GIVEN** a LaneBuilder result builder
- **WHEN** a lane is defined with no actions
- **THEN** the lane creates with an empty action array
- **AND** lane execution completes immediately

### Requirement: ActionBuilder Result Builder

The system SHALL provide an ActionBuilder result builder for nested action composition.

#### Scenario: Build array of actions

- **GIVEN** an ActionBuilder result builder
- **WHEN** multiple actions are provided
- **THEN** all actions are collected into an array
- **AND** the order is preserved

#### Scenario: Optional action handling

- **GIVEN** an ActionBuilder with optional support
- **WHEN** an action returns nil
- **THEN** the nil action is filtered out
- **AND** other actions remain in sequence

### Requirement: Type Safety

Result builders MUST maintain compile-time type safety.

#### Scenario: Compile-time action validation

- **GIVEN** a LaneBuilder expecting AnyAction
- **WHEN** a non-Action type is used in the builder
- **THEN** compilation fails with a type error
- **AND** the error message indicates the expected type

#### Scenario: Sendable conformance

- **GIVEN** LaneBuilder and ActionBuilder
- **WHEN** used in concurrent contexts
- **THEN** they conform to Sendable requirements
- **AND** no data races occur
