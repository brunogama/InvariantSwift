# Discard semantics (assumptions)

## Goal
Assumptions must not silently fail by returning an invalid test value.

## Design

- Remove assumption handling from `Gen.suchThat` for property testing.
- Introduce runner-level discards:
  - generate candidate
  - if assumption fails: `discarded += 1`, continue
  - if `discarded > maxDiscarded`: return `.gaveUp`

## API options

### Option A (minimal changes)
- Keep `Property.filter`, but implement it as a runner feature:
  - `Property` stores `assumptions: [(T) -> Bool]`
  - runner evaluates assumptions and discards accordingly.

### Option B (clearer)
- Add explicit `Property.assume(_:)` chain:
  - `Property(generator:).assume { ... }.check { ... }`

## Acceptance criteria

- A property with a highly selective assumption returns `.gaveUp` with accurate discard count.
- The runner never evaluates `predicate` on values that fail assumptions.
- Failure output reports discard count and replay token.
