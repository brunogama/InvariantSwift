---
id: json-report-schema
title: Versioned JSON report schema for CI
capability: pbt-core
status: proposed
---

# Versioned JSON report schema for CI

## Summary
Emit a stable JSON report for each run containing stats, distributions, failures, replay token, and shrink trace.

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
