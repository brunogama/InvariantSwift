---
id: S020
title: Introduce `ShrinkTree` model
epic: E002
priority: P0
status: done
dependencies: []
---

## Goal
Represent shrinking as a tree to support dependent shrinking and non-greedy search.

## Scope
- Add `Sources/InvariantSwift/Core/ShrinkTree.swift`:
  - `struct ShrinkTree<T> { let value: T; let children: () -> [ShrinkTree<T>] }`
  - helpers: `map`, `flatten(depth:)` (optional)
- Add bridging helpers:
  - `Shrink<T>.tree(_ value: T) -> ShrinkTree<T>` (initially list-based: children from current `shrink(value)`)

## Acceptance criteria
- Code compiles and is covered by a basic unit test.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
- new: `Sources/InvariantSwift/Core/ShrinkTree.swift`

## Tests to add
- `Tests/FunctionalTesting/ShrinkTreeTests.swift` (tree creation and traversal)
