# Change: modularize-targets

    ## Why
    Mixing core runtime, macros, plugins, and advanced experiments in one target increases build cost and brittleness.

    ## What Changes
    - Split SwiftPM targets/products:
  - `InvariantSwiftCore` (Gen, ShrinkTree, Property, ReplayToken, FailureReport)
  - `InvariantSwift` (re-exports core + stable generator set)
  - `InvariantSwiftMacros` (build-time only)
  - `InvariantSwiftTesting` (Swift Testing adapters)
  - `InvariantSwiftExperimental` (coverage-guided, SMT, linearizability, etc.)
- Keep source layout aligned with products.

    ## Impact
    - Breaking for internal imports; can be made mostly source-compatible via re-exports and product aliases.

    ## Non-Goals
    - N/A

    ## Risks
    - SwiftPM product re-exports can be confusing; must document import paths.
