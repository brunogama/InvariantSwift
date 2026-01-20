---
id: S022
title: Implement `Shrink.contramap` correctly (or remove it)
epic: E002
priority: P1
status: todo
dependencies: [S020]
---

## Problem
Current `Shrink.contramap` returns the original input repeatedly, producing no real shrinks.

## Scope
Choose one:
A) Remove `contramap` from public API and provide guidance to implement custom shrinkers directly.
B) Re-implement using a pair of functions `to: (U)->T` and `from: (T)->U` OR by returning a `ShrinkTree<U>` through a provided constructor.

## Acceptance criteria
- No shrink candidate is the same instance/value repeated without reason.
- Tests demonstrate shrinking a wrapper type works.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
- (optional) new tests in `Tests/FunctionalTesting/ShrinkContramapTests.swift`
