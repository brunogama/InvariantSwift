---
id: float-generation-shrinking
title: Float/Double generation and shrinking (robust modes)
capability: pbt-generators
status: proposed
---

# Float/Double generation and shrinking (robust modes)

## Summary
Define robust floating point generation/shrinking with explicit NaN/inf policies and deterministic convergence behavior.

## Motivation
- Improve correctness, determinism, and developer trust.
- Keep the PBT core contract sound before adding “advanced” features.

## Scope
- Implement requirements in the spec delta under `specs/pbt-generators/spec.md`.
- Add tests for all scenarios and edge cases.

## Non-goals
- No unrelated refactors.
- No expanding to additional features not listed in the delta.

## Acceptance
- All scenarios in the delta pass.
- Deterministic output for the same seed/replay token across supported platforms/toolchains.
