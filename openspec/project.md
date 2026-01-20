# Project Context: InvariantSwift

## Summary
InvariantSwift is a Swift property-based testing (PBT) framework built as a SwiftPM package. The project includes a runtime engine (`InvariantSwift`), SwiftSyntax-based macros (`InvariantSwiftMacros`), a functional test runner CLI (`FuncTestCLI`), a code generation CLI (`GhostwriterCLI`), and SwiftPM plugins under `Plugins/`.

This repository is currently in an MVP/experimental state and contains advanced feature ambitions (coverage guidance, model-based testing, state machines). The immediate goal is to make the *core PBT contract* correct and trustworthy: deterministic replay, correct discard semantics, and high-quality shrinking.

## Tech stack
- SwiftPM (Swift 6.x toolchain)
- SwiftSyntax macros (heavy toolchain-coupled dependency)
- Swift Testing integration target(s)
- Optional plugins that run local tools during builds/tests

## Conventions
- Prefer deterministic behavior and stable output over micro-optimizations.
- Avoid runtime crashes and forced casts in core PBT engine.
- Separate build-time concerns (macros, plugins) from runtime where possible.
- Public API stability: avoid breaking renames without a deprecation path.

## Definitions
- **Iteration**: one generated test input evaluated by a property.
- **Discard**: generated value that does not satisfy assumptions/preconditions.
- **Gave Up**: property run stopped because discards exceeded `maxDiscarded`.
- **Shrink**: process of reducing a failing input to a smaller counterexample.
- **Replay Token**: opaque string that reproduces the exact failing run.

## Acceptance bar (for P0 correctness changes)
- Deterministic reproduction from a single replay token.
- Assumptions NEVER allow invalid values to pass silently.
- Shrinking is deterministic and produces monotonically "smaller" counterexamples.
- No forced casts in core shrink logic.
