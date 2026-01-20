# Proposal: Refactor package boundaries (runtime vs macros)

## Why
SwiftSyntax/macros are toolchain-coupled and heavy. Runtime users should not pay that cost unless they opt in.

## What
Split targets:
- `InvariantSwiftCore` (runtime engine)
- `InvariantSwiftTesting` (Swift Testing glue)
- `InvariantSwiftMacros` (macro implementation)
- `InvariantSwiftMacroAPI` (light declarations for macro usage)

## Out of scope
- API redesign beyond modularization
