---
id: timeouts-cancellation
title: Timeouts and cooperative cancellation
capability: pbt-core
status: proposed
---

# Timeouts and cooperative cancellation

## Summary
Add per-property timeouts (primarily for async predicates) and deterministic handling of task cancellation.

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
