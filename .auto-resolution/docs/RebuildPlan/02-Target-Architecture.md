# Target Architecture

## Principle: a small, correct core
The core must stand alone with zero macros and zero SwiftSyntax dependencies.

### Recommended product/target split (later refactor)
- `InvariantSwiftCore`:
  - `Gen`, `Shrink`, `Property`, `PropertyRunner`, replay, statistics, shrink search
- `InvariantSwiftTesting`:
  - Swift Testing adapter and reporting utilities
- `InvariantSwiftMacros`:
  - macro implementations (SwiftSyntax)
- `InvariantSwiftPlugin`:
  - command plugin that shells out to CLI (no networking by default)

## Why split
- Keeps SwiftSyntax out of runtime builds.
- Makes “core correctness” independently testable.
- Enables other front-ends (CLI, fuzzing) without circular dependencies.
