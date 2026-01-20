---
id: S030
title: Define replay token format and implement replay execution
epic: E003
priority: P1
status: todo
dependencies: [S010, S021]
---

## Scope
- Define `Replay` structure.
- Print replay token on failure.
- Add a runner entrypoint `runProperty(replay: ...)` that replays exactly.

## Acceptance criteria
- A failure can be reproduced by running the test with the printed replay token.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- `Docs/RebuildPlan/06-Replay-Determinism.md`
