---
id: S040
title: Implement replay token format and printing
epic: E003
priority: P0
status: done
dependencies: [S010]
---

## Scope
- Define `Replay` struct and stable encoder.
- Include replay token in failure output.

## Acceptance criteria
- Copy-pasting replay token reproduces the same failing case.

## Files to touch
- `Sources/InvariantSwift/Core/Property.swift`
- new file: `Sources/InvariantSwift/Core/Replay.swift`
