---
id: S001
epic: E001
status: todo
owner: llm
---

# S001: Implement discard-aware runner

## Problem
Assumptions are implemented by filtering generators (`Gen.suchThat`) which can return invalid values. Runner does not count discards or produce `.gaveUp`.

## Scope
- Add discard counting to the runner.
- Ensure predicates are only evaluated on values that satisfy assumptions.

## Acceptance criteria
- `Property` supports an assumption predicate separate from the assertion predicate.
- `PropertyRunner.runProperty` tracks `discarded`.
- If `discarded > config.maxDiscarded` return `.gaveUp(discarded:tested:seed:...)`.
- No code path evaluates the assertion predicate on an input that fails the assumption.

## Implementation notes
- Prefer attaching assumptions to `Property` rather than rewriting generators.
- Keep `Gen.suchThat` but mark it as a low-level helper; do not use it for `Property.filter`.

## Files
- `Sources/InvariantSwift/Core/Property.swift`
- (optional) `Sources/InvariantSwift/Core/Generator.swift` (docs/annotation only)
- `Tests/FunctionalTesting/*` add tests for give-up/discard counting
