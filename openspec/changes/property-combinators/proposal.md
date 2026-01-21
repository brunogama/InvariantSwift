---
id: property-combinators
title: Property combinators: and/or/implies
capability: pbt-core
status: proposed
---

# Property combinators: and/or/implies

## Summary
Add compositional operators for properties with correct short-circuit, discard semantics, and meaningful reporting.

## Motivation
- Improve correctness, determinism, and developer trust.
- Keep the PBT core contract sound before adding “advanced” features.

## Scope
- Implement requirements in the spec delta under `specs/pbt-core/spec.md`.
- Add tests for all scenarios and edge cases.

## Non-goals
- No unrelated refactors.
- No expanding to additional features not listed in the delta.

## Acceptance
- All scenarios in the delta pass.
- Deterministic output for the same seed/replay token across supported platforms/toolchains.
