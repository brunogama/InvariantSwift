---
id: S030
title: Introduce ShrinkTree model
epic: E002
priority: P0
status: done
dependencies: []
---

## Scope
- Add `ShrinkTree<T>` type.
- Provide adapters from existing `Shrink<T>` list-based API to a tree.

## Acceptance criteria
- `ShrinkTree` exists with deterministic child enumeration.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift` (or new file under Core)

## Tests to add
- Tree enumeration is stable.
