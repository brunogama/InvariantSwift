---
id: S023
title: Implement `Shrink.flatMap` for dependent shrinking
epic: E002
priority: P1
status: done
dependencies: [S020]
---

## Problem
Current `Shrink.flatMap` is a stub returning no candidates.

## Scope
Implement dependent shrinking using `ShrinkTree`:
- `flatMap` should create a tree where children are:
  - shrinks of the outer value mapped through `f`, and
  - shrinks of the inner value produced by `f(outer)`.

## Acceptance criteria
- Unit tests demonstrate shrinking works for a dependent pair generator (e.g., generate `NonEmptyArray` where count determines contents).

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift` (or move shrink combinators to a new file)
- `Tests/FunctionalTesting/ShrinkDependentTests.swift`
