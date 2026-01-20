---
id: parallel-checking
title: Parallel checking with stable seeding
capability: pbt-core
status: proposed
---

# Parallel checking with stable seeding

## Summary
Enable parallel evaluation of iterations while preserving deterministic outcomes via seed splitting and deterministic failure aggregation.

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
