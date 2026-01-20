---
id: S034
title: Fix Gen.flatMap shrinking for dependent generators
epic: E002
priority: P0
status: done
dependencies: [S030, S031]
---

## Scope
- Ensure `Gen.flatMap`-composed generators shrink both:
  - the “outer” value
  - the dependent “inner” value

## Acceptance criteria
- A property using dependent generation produces a minimal counterexample.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
- `Sources/InvariantSwift/Core/Property.swift`

## Tests to add
- Dependent generator shrink regression test.
