---
id: S010
title: Implement discard-aware PropertyRunner and `.gaveUp`
epic: E001
priority: P0
status: done
dependencies: []
---

## Problem
The current runner does not track discards, and assumptions are implemented via `Gen.suchThat`, which can return invalid values.

## Scope
1. Extend `Property` to optionally carry an `assumption: (T) -> Bool`.
2. Update `PropertyRunner.runProperty` to:
   - increment `discarded` when assumption fails
   - stop and return `.gaveUp` when `discarded > config.maxDiscarded`
   - never call `predicate` when assumption fails
3. Ensure returned results include `discarded` count.

## Non-goals
- No ShrinkTree in this story.

## Acceptance criteria
- A property with an always-false assumption returns `.gaveUp` after `maxDiscarded + 1` discards.
- A property with a restrictive assumption never evaluates `predicate` for discarded cases.
- Existing tests pass, new tests added.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- (optional) `Sources/InvariantSwift/Core/Generator.swift` (deprecate `suchThat` usage in `Property.filter`)

## Tests to add
- `Tests/FunctionalTesting/DiscardSemanticsTests.swift`:
  - gaveUp when assumption too restrictive
  - predicate not invoked for discarded values
