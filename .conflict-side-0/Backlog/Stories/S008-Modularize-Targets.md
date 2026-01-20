---
id: S008
epic: E003
status: todo
owner: llm
depends_on: [S001,S004]
---

# S008: Modularize targets

## Problem
Runtime library depends on macros target, pulling SwiftSyntax surface area.

## Scope
- Split into Core / Testing / Macros / MacroAPI.

## Acceptance criteria
- `InvariantCore` builds without SwiftSyntax dependency.
- `InvariantSwift` (umbrella) can re-export for convenience.
- Tests updated to import correct modules.
