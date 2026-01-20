# PBT Core Specification

## Purpose

Define the behavior, constraints, and contracts of InvariantSwift's property-based testing core (Gen/Shrink/Property/Runner).

## Definitions

- **Iteration**: one generated test input evaluated by a property predicate
- **Discard**: generated value that does not satisfy assumptions/preconditions
- **Gave Up**: property run stopped because discards exceeded `maxDiscarded`
- **Shrink**: process of reducing a failing input to a smaller counterexample

---

## Requirements

### Requirement: Deterministic Generation

The system MUST produce identical samples for a given generator when initialized with the same seed and size.

#### Scenario: Same seed yields the same sample

- GIVEN a generator `G`
- AND seed `S`
- AND size `Z`
- WHEN a sample is drawn from `G` with `(S, Z)` two times
- THEN the two samples are equal

### Requirement: Runner Evaluates a Predicate

The system MUST evaluate a predicate over generated values for a configured number of iterations.

#### Scenario: Property holds for all iterations

- GIVEN a predicate `P` that returns true for all inputs
- WHEN the runner executes `N` iterations
- THEN the result is `.success(iterations: N)`

#### Scenario: Property fails on some input

- GIVEN a predicate `P` that returns false for some input
- WHEN the runner finds such an input after `K` iterations
- THEN the result is `.failure` with the counterexample and shrunk value

### Requirement: Runner Tracks Discards

The system MUST track discarded test cases and return `.gaveUp` when too many are discarded.

#### Scenario: Assumptions cause discards

- GIVEN a property with assumption `A` that filters many values
- WHEN the runner discards more than `maxDiscarded` values
- THEN the result is `.gaveUp(discarded: D, iterations: I)`

### Requirement: Assumptions via Property-Level Predicates

Properties support explicit assumptions through the `assumption` parameter, providing proper discard tracking.

#### Scenario: Property-level assumption provides discard semantics

- GIVEN a `Property(generator:assumption:predicate:)`
- WHEN a generated value fails the assumption
- THEN it is counted as discarded (not failed)
- AND does not reach the predicate

### Requirement: Generator-Level Filtering (Gen.suchThat)

Generator-level filtering (`Gen.suchThat`) provides convenience but with bounds on retries.

#### Scenario: Filtered generation with bounded retries

- GIVEN a generator filtered by a predicate via `Gen.suchThat`
- WHEN the predicate rarely holds
- AND the generator retries a bounded number of times
- THEN it may return the last generated value (which may not satisfy the filter)

> **Note**: For robust discard semantics, prefer `Property(assumption:)` or `EvaluatingProperty` over `Gen.suchThat`.

---

## Property Types

| Type | Predicate Returns | Discard Mechanism |
|------|------------------|-------------------|
| `Property<T>` | `Bool` | `assumption:` parameter |
| `ThrowingProperty<T>` | `throws Bool` | `assumption:` parameter |
| `EvaluatingProperty<T>` | `PropertyEvaluation` | `.discard(reason:)` in body |

---

## Known Limitations

1. **Gen.suchThat is best-effort**: The filter may not be satisfied after max retries
2. **Shrinking respects assumptions**: Shrunk candidates failing assumptions are skipped
3. **Per-iteration timeout is coarse**: Measured after predicate completes, not interrupted mid-execution
