---
id: S011
title: Stop using Gen.suchThat for property assumptions
epic: E001
priority: P0
status: done
dependencies: [S010]
---

## Scope
- Deprecate `Property.filter` implementation based on `Gen.suchThat`.
- Introduce `Property.assuming(...)` (or equivalent) that stores the assumption and lets the runner handle discards.
- Keep `Gen.suchThat` for niche generator filtering, but make it safe (see story S012).

## Acceptance criteria
- `Property.filter` no longer relies on generator filtering OR is clearly documented as unsafe and replaced by `assuming`.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- `Sources/InvariantSwift/Core/Generator.swift`
