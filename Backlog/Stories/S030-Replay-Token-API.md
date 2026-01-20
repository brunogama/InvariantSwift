---
id: S030
title: Define replay token format and API
epic: E003
priority: P1
status: todo
dependencies: [S010]
---

## Goal
Make failures reproducible by copy-pasting a replay token.

## Scope
- Add `Replay` type (Codable): seed, iterations, sizeScheduleId, optional rngAlgorithmId.
- Add `PropertyRunner.runProperty(..., replay: Replay?)` overload to replay failures deterministically.
- Update failure output printing in Swift Testing adapter (or runner debug description).

## Acceptance criteria
- Re-running with the replay token reproduces the same failing counterexample (before shrinking).
- Replay token format is documented in `Docs/RebuildPlan/06-Replay-Determinism.md`.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- `Sources/InvariantSwift/Core/Seed.swift` (if needed)
- `Docs/RebuildPlan/06-Replay-Determinism.md`

## Tests to add
- `Tests/FunctionalTesting/ReplayTests.swift`
