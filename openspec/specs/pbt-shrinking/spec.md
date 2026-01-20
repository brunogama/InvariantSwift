# Shrinking Specification

## Purpose

Describe the shrinking behavior and invariants required for reliable counterexample minimization.

## Definitions

- **Shrink**: Function producing simpler candidates from a value
- **ShrinkTree**: Lazy tree of a value and its shrink candidates
- **BFS Shrinking**: Breadth-first search for minimal counterexample

---

## Requirements

### Requirement: Shrink Produces Candidate Values

The system MUST provide a way to produce simpler candidates from a value.

#### Scenario: Integer shrinking produces smaller magnitudes

- GIVEN a shrinker for `Int`
- WHEN shrinking the value `100`
- THEN at least one candidate has absolute value < 100

### Requirement: Shrink Search Is Deterministic

Given identical inputs (seed, shrink ordering), the shrink search MUST yield the same minimal counterexample.

#### Scenario: Repeat shrink returns the same minimal value

- GIVEN a failing value `V` and its shrink candidates
- WHEN shrink is run twice under the same ordering
- THEN the minimal found value is equal

### Requirement: Shrink Search Uses BFS

The runner MUST use breadth-first search on `ShrinkTree` to find minimal counterexamples.

#### Scenario: BFS finds smaller than greedy

- GIVEN a shrink tree with branching candidates
- WHEN BFS is used with sufficient budget
- THEN it finds the minimal value satisfying the failure predicate

### Requirement: Shrinking Respects Assumptions

The runner MUST filter shrink candidates through the property's assumption before testing them.

#### Scenario: Invalid shrink candidates are skipped

- GIVEN a property with assumption `A`
- WHEN shrinking a failing value
- THEN candidates failing `A` are never tested against the predicate

---

## Implementation Notes

### ShrinkTree vs Shrink

| API | Status | Use Case |
|-----|--------|----------|
| `Shrink<T>` | Active | Defining shrink strategies |
| `Shrink.flatMap` | Deprecated | Use `ShrinkTree.flatMap` instead |
| `Shrink.contramap` | Deprecated | May not produce valid shrinks |
| `ShrinkTree<T>` | Active | BFS search, lazy evaluation |
| `ShrinkTree.flatMap` | Active | Dependent shrinking |

---

## Known Limitations

1. **`Shrink.contramap` is problematic**: Returns same value repeatedly in some cases
2. **`Shrink.flatMap` is stubbed**: Use `ShrinkTree.flatMap` for correct dependent shrinking
3. **Shrink budget limits exploration**: Very deep trees may not find true minimal
