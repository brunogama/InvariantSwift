# State Machine Macro Capability

**Note**: This capability is targeted for v1.1. This specification documents the intended design.

## ADDED Requirements

### Requirement: StateMachine Macro Declaration
The system SHALL provide a `@StateMachine` macro that defines a model for state machine testing.

#### Scenario: Basic state machine definition
- **GIVEN** a struct annotated with `@StateMachine`
- **WHEN** the macro expands
- **THEN** it SHALL generate command types for each `@Command` method
- **AND** generate a command generator combining all commands

### Requirement: Command Macro Declaration
The system SHALL provide a `@Command` macro that marks methods as state machine commands.

#### Scenario: Command method marking
- **GIVEN** a method annotated with `@Command`
- **WHEN** the macro expands
- **THEN** it SHALL be included in the generated command enum

### Requirement: State Machine Model Structure
A `@StateMachine` annotated type SHALL follow a specific structure.

#### Scenario: State properties
- **GIVEN** `@StateMachine struct CounterModel { var count: Int = 0 }`
- **WHEN** used in testing
- **THEN** `count` SHALL represent the model state

#### Scenario: Command methods
- **GIVEN** `@Command mutating func increment() { count += 1 }`
- **WHEN** the command is executed
- **THEN** it SHALL mutate the model state

### Requirement: Commands Generator
The system SHALL provide a way to generate command sequences.

#### Scenario: Commands attribute
- **GIVEN** `@Commands(model: CounterModel.self, count: 1...20) commands: [CounterCommand]`
- **WHEN** used with `@Property`
- **THEN** it SHALL generate sequences of 1-20 commands

### Requirement: State Machine Test Pattern
The generated test pattern SHALL compare model and system under test.

#### Scenario: Model-SUT comparison
- **GIVEN** a state machine model and real implementation
- **WHEN** executing a command sequence
- **THEN** each command SHALL be executed on both model and SUT
- **AND** their states SHALL be compared after each command

### Requirement: v1.1 Implementation Status
This capability SHALL NOT be implemented in v1.0.

#### Scenario: Placeholder files
- **GIVEN** v1.0 release
- **WHEN** checking StateMachineMacro
- **THEN** placeholder files MAY exist
- **AND** the macro SHALL NOT be registered in MacroPlugin

#### Scenario: Documentation
- **GIVEN** v1.0 documentation
- **WHEN** describing state machine testing
- **THEN** it SHALL note this feature is planned for v1.1
