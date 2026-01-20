---
id: S023
title: Replace placeholder `Shrink.flatMap`
epic: E002
priority: P1
status: todo
dependencies: [S020]
---

## Scope
- Remove `Shrink.flatMap` if unused OR implement it properly using `ShrinkTree`.

## Acceptance criteria
- `Gen.flatMap` can build a dependent shrink tree without relying on a stub.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
