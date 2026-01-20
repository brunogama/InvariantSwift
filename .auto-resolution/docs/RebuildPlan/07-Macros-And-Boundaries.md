# Macros and Boundaries

## Principle
Macros must never be the only way to use the library.

## Requirements
- Every macro expands to a public API call that is usable directly.
- Macro tests must assert expansion correctness and failure formatting.
- Avoid pulling SwiftSyntax into runtime targets.

## Suggested refactor
- Move macro declarations into a thin target and keep implementation isolated.
