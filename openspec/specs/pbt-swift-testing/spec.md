# Swift Testing Integration Specification

## Purpose

Define how InvariantSwift integrates with Apple's Swift Testing framework (assertion reporting, async support).

---

## Requirements

### Requirement: Single Failure Report per Property

A property test SHOULD report a single failure containing the minimal counterexample and reproduction data.

#### Scenario: Property fails once with minimal example

- GIVEN a property that fails for some inputs
- WHEN executed under Swift Testing
- THEN the test reports one failure including the minimal counterexample and seed

### Requirement: Async Properties Are Supported

The integration MUST support evaluating async properties.

#### Scenario: Async predicate is awaited

- GIVEN an async predicate
- WHEN running a property with `runPropertyWithTimeout`
- THEN the predicate is awaited for each iteration

### Requirement: Throwing Properties Are Supported

Properties with throwing predicates MUST classify thrown errors as failures.

#### Scenario: Thrown error is captured

- GIVEN a `ThrowingProperty<T>` with a predicate that throws
- WHEN the property is run
- THEN result is `.failure(reason: .threwError(description))`

---

## Property Types for Swift Testing

| Type | Predicate | Use Case |
|------|-----------|----------|
| `Property<T>` | `(T) -> Bool` | Simple boolean checks |
| `ThrowingProperty<T>` | `(T) throws -> Bool` | Predicates that may throw |
| `EvaluatingProperty<T>` | `(T) -> PropertyEvaluation` | Explicit pass/fail/discard |

---

## Known Limitations

1. **Non-async Property predicate**: `Property<T>` predicate is sync; use `runPropertyWithTimeout` for async
2. **Single counterexample reported**: Only the shrunk counterexample is reported, not all failures
3. **No native parameterization**: Property tests don't use Swift Testing's parameterized test features
