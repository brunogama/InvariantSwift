---
id: S011
title: Make `Gen.suchThat` safe or deprecate it
epic: E001
priority: P0
status: done
dependencies: [S010]
---

## Problem
`Gen.suchThat` returns an arbitrary value after max attempts, potentially violating the predicate.

## Options (choose one and document)
A) Deprecate `suchThat` for property assumptions. Keep it for non-critical filtering but make semantics explicit.
B) Change `suchThat` to return `Gen<Optional<T>>` or throw a `GenerationError.tooManyDiscards`.
C) Remove `suchThat` from public API and provide safe combinators.

## Acceptance criteria
- `Property.filter` no longer relies on unsafe generator filtering.
- If `suchThat` remains, it never returns a value that violates the predicate without signalling (Optional/throw).
- Docs updated in `Docs/RebuildPlan/05-Discard-Semantics.md`.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
- `Sources/InvariantSwift/Core/Property.swift`
- `Docs/RebuildPlan/05-Discard-Semantics.md`

## Tests to add
- A deterministic test verifying the new behaviour of `suchThat`.
