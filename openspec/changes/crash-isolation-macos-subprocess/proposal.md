---
id: crash-isolation-macos-subprocess
title: Crash isolation on macOS via subprocess runner
capability: pbt-core
status: proposed
---

# Crash isolation on macOS via subprocess runner

## Summary
Provide true crash isolation for fatalError/precondition failures by running evaluations in a subprocess on macOS.

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
