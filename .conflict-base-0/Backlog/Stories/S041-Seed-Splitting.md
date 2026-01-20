---
id: S041
title: Add deterministic seed splitting utilities for composite generators
epic: E003
priority: P1
status: done
dependencies: [S040]
---

## Scope
- Add a utility to derive child RNGs/seeds from a parent RNG state.
- Use it in `zip`, `array`, and other composite generators.

## Acceptance criteria
- Composite generators do not unexpectedly couple values due to shared RNG consumption.

## Files to touch
- `Sources/InvariantSwift/Core/Generator.swift`
- new file if needed: `Sources/InvariantSwift/Core/SeedSplitting.swift`
