
# Project: InvariantSwift

## Domain
Property-based testing (PBT) framework for Swift (SwiftPM). Includes:
- core PBT engine (generators, shrinking, runner, replay)
- Swift Testing integration and macros
- optional tooling (CLI, plugins, ghostwriter)

## Non-negotiables (project demands)
1. Determinism: same seed + config => same generated values and shrink path.
2. Contract correctness: assumptions/discards must never silently test invalid inputs.
3. Shrinking quality: minimal counterexamples with predictable search strategy.
4. Ergonomics: Swift Testing output must be readable and reproducible.
5. Trust: plugins must not request network permission by default.
6. Modularity: macros/build-time deps must not leak into runtime/core.

## Codebase reality (as of 2026-01-20)
- Core types exist under `Sources/InvariantSwift/Core/` (Gen, ShrinkTree, ReplayToken, Property).
- Advanced/experimental modules exist under `Sources/InvariantSwift/Advanced/` and `Fuzzing/`.
- Generators exist under `Sources/InvariantSwift/Generators/`.
- CLI & plugins exist under `Sources/FuncTestCLI/` and `Plugins/`.

## Conventions
- Requirements use MUST/SHALL language.
- Every requirement has at least one Scenario.
- Prefer adding/modifying requirements instead of creating new capabilities unless truly distinct.
- Changes are verb-led kebab-case ids (e.g., `add-classification-reporting`).
