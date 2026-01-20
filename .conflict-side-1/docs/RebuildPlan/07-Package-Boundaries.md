# Package Boundaries and Dependencies

## Problem
The runtime target depends on the macros target. This risks pulling SwiftSyntax into consumer builds and tangles build-time and run-time concerns.

## Plan
Phase the refactor:
1. Make core semantics correct without target splits.
2. Introduce `InvariantSwiftCore` and move non-macro code there.
3. Make `InvariantSwift` re-export `InvariantSwiftCore` for compatibility.
4. Ensure macros depend on core, never the other way around.

## Acceptance criteria
- `InvariantSwiftCore` has no SwiftSyntax dependencies.
- Consumers can use PBT without enabling macros.
