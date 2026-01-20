---
id: S002
epic: E001
priority: P0
title: Restrict `Gen.suchThat` usage and prevent silent invalid outputs
status: done
owners: ["llm"]
dependencies: ["S001"]
files:
  - Sources/InvariantSwift/Core/Generator.swift
---

## Problem
`Gen.suchThat` returns a value after max attempts even if predicate fails.

## Scope
- For PBT path, stop using `suchThat` for assumptions (handled by runner).
- Keep `suchThat` as a utility, but make its behavior explicit:
  - either return `Optional<T>` / throw / precondition
  - or provide `suchThatOrGiveUp` returning `Gen<Result<T,Discarded>>`

## Acceptance criteria
- Property assumptions no longer rely on `Gen.suchThat`.
- The semantics of `suchThat` are non-misleading in docs.
