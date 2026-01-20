---
id: S040
title: Create `InvariantSwiftCore` target and move core files
epic: E004
priority: P2
status: todo
dependencies: [S010, S021]
---

## Scope
- Introduce new target `InvariantSwiftCore`.
- Move core files into it.
- Keep `InvariantSwift` as a facade/re-export.

## Acceptance criteria
- `InvariantSwiftCore` builds with no SwiftSyntax deps.

## Files to touch
- `Package.swift`
- `Sources/InvariantSwift/*` (moves)
