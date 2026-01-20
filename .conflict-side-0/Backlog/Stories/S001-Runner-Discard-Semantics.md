---
id: S001
epic: E001
priority: P0
title: Implement discard-aware runner semantics
status: done
owners: ["llm"]
dependencies: []
files:
  - Sources/InvariantSwift/Core/Property.swift
  - Sources/InvariantSwift/Core/Generator.swift
  - Tests/FunctionalTesting/**
---

## Problem
Assumptions are implemented via `Gen.suchThat` which returns an invalid value after 100 attempts, and the runner never produces `.gaveUp`.

## Scope
- Move discard handling into `PropertyRunner.runProperty`.
- Ensure `predicate` is never evaluated for discarded cases.

## Implementation notes
- Add `assumptions: [(T) -> Bool]` to `Property` or similar.
- `Property.filter` should append an assumption rather than rewriting the generator.
- Runner loop:
  - generate candidate
  - if any assumption fails: discarded += 1; continue
  - if discarded > maxDiscarded: return `.gaveUp(...)`

## Acceptance criteria
- With selective assumptions, runner returns `.gaveUp` and reports `discarded`.
- No invalid (assumption-failing) values reach predicate.
- Existing basic properties still pass.

## Tests
- Add a property with assumption `value == 0` using `Gen.int(in: 0...1_000_000)` and low maxDiscarded; must give up.
- Add a property where assumption always true; discard count remains 0.
