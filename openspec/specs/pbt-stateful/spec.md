# Stateful Testing Specification

## Purpose

Define model-based/stateful property testing (commands, state model, postconditions, shrinking sequences).

## Definitions

- **Command**: Action with precondition, state transition, and postcondition
- **State**: Abstract model state tracking system under test
- **Linearizability**: Concurrent execution matches some sequential history

---

## Requirements

### Requirement: Commands Define Preconditions and Transitions

A command MUST define a precondition, state transition, and postcondition.

#### Scenario: Invalid commands are discarded

- GIVEN a command whose precondition fails in state `S`
- WHEN generating command sequences
- THEN the command is discarded and does not execute

### Requirement: Command Sequences Shrink

Failing command sequences MUST be shrinkable (length and content).

#### Scenario: Sequence shrinks to minimal failing prefix

- GIVEN a failing command sequence
- WHEN shrinking
- THEN the minimal failing sequence is returned

### Requirement: State Transitions Are Tracked

The runner MUST track model state through command execution.

#### Scenario: Model state updates after valid command

- GIVEN command `C` with initial state `S0`
- WHEN `C` is executed
- THEN state becomes `C.apply(S0)`

---

## Command Protocol

```swift
public protocol Command {
  associatedtype State
  
  func precondition(_ state: State) -> Bool
  func apply(_ state: State) -> State
  func execute() async throws
  func postcondition(_ state: State, result: Void) -> Bool
}
```

---

## Known Limitations

1. **SUT execution required**: Commands must call real system; no pure model checking
2. **Async-only execution**: `execute()` is async, may need sync wrapper
3. **Sequence shrinking complexity**: Very long sequences may hit shrink budget
