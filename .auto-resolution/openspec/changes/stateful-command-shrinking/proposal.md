---
id: stateful-command-shrinking
title: Stateful testing: shrink command sequences
capability: pbt-stateful
status: proposed
---

# Stateful testing: shrink command sequences

## Summary
Shrink failing command sequences to a minimal reproducer using chunk removal + per-command shrinking.

## Motivation
- Improve correctness, determinism, and developer trust.
- Keep the PBT core contract sound before adding “advanced” features.

## Scope
- Implement requirements in the spec delta under `specs/pbt-stateful/spec.md`.
- Add tests for all scenarios and edge cases.

## Non-goals
- No unrelated refactors.
- No expanding to additional features not listed in the delta.

## Acceptance
- All scenarios in the delta pass.
- Deterministic output for the same seed/replay token across supported platforms/toolchains.
