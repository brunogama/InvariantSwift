---
id: E004
title: Package Boundaries
objective: Separate runtime core from macros/SwiftSyntax.
exit_criteria:
  - `InvariantSwiftCore` has no SwiftSyntax dependencies.
  - `InvariantSwiftMacros` depends on core, not vice versa.
  - Public API compatibility is preserved (or shims are provided).
---

## Stories
- S040 Create `InvariantSwiftCore` target and move core files
- S041 Update products to export core
- S042 Update macro target dependencies
- S043 Update docs and migration notes
