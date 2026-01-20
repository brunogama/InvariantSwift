# OpenSpec Workflow Instructions (InvariantSwift)

## Ground rules
- Specs are the source of truth: read `openspec/project.md` and relevant `openspec/specs/**/spec.md` before writing code.
- All work happens through a change folder under `openspec/changes/<change-id>/`.
- Change IDs MUST be unique, verb-led, kebab-case (e.g. `fix-discard-semantics`, `add-replay-token`).
- Each change folder MUST contain:
  - `proposal.md`
  - `tasks.md`
  - `specs/<capability>/spec.md` deltas for every impacted capability
  - `design.md` only if architectural decisions are required

## How to work
1) Identify impacted capabilities under `openspec/specs/`.
2) Draft/adjust proposal and deltas until they match required behavior.
3) Implement tasks in order; mark tasks complete as you go.
4) Keep changes small and atomic. If scope explodes, create a new change.
5) When done, archive the change (move folder into `openspec/archive/`) and fold deltas into the living specs under `openspec/specs/`.

## Repository-specific constraints
- Swift Package Manager package.
- Primary targets: `InvariantSwift` (runtime), `InvariantSwiftMacros` (SwiftSyntax macros), `FuncTestCLI`, `GhostwriterCLI`, plugins under `Plugins/`.
- Top rewrite priorities:
  1) Correct discard/assumption semantics (stop silently generating invalid values)
  2) Correct shrinking foundations (ShrinkTree + deterministic shrink search)
  3) Deterministic replay tokens and reliable failure reporting
  4) Split heavy build-time dependencies away from runtime where possible

## Safety/trust
- Do not add network permissions to SwiftPM plugins unless explicitly required and documented.
- Prefer opt-in behavior for telemetry/coverage uploads.
