---
id: S012
title: Make Gen.suchThat safe (no invalid fallback)
epic: E001
priority: P1
status: todo
dependencies: [S010]
---

## Scope
Change `Gen.suchThat` so it never returns an invalid value.
Options (pick one and document):
- Return `Gen<T?>` and yield `nil` when it cannot satisfy.
- Throw on exhaustion.
- Provide `suchThatOrFail` and deprecate current behavior.

## Acceptance criteria
- It is impossible for `suchThat` to emit a value that fails the predicate.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`

## Tests to add
- Exhaustion case is deterministic and observable.
