---
id: S010
title: Implement discard-aware PropertyRunner and .gaveUp
epic: E001
priority: P0
status: todo
dependencies: []
---

## Scope
- Update `PropertyRunner.runProperty` to track discards and return `.gaveUp` when `maxDiscarded` is exceeded.
- Assumptions must be evaluated in the runner.

## Acceptance criteria
- A property with a restrictive assumption returns `.gaveUp` rather than silently testing invalid values.
- `PropertyResult` contains `discarded` count.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`

## Tests to add
- A property that discards most values must hit `.gaveUp` deterministically.
