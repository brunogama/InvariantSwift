---
id: S050
title: Create InvariantSwiftCore target and migrate non-macro code
epic: E004
priority: P1
status: done
dependencies: [S010, S030]
---

## Scope
- Add a new target in `Package.swift`.
- Move `Core/` non-macro sources.
- Update imports and target dependencies.

## Acceptance criteria
- Core builds without SwiftSyntax.
- Tests run against core.
