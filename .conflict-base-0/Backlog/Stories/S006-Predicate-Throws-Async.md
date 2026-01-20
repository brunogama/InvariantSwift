---
id: S006
epic: E003
priority: P1
title: Align predicate signature with failure reasons (throws/async) or remove unreachable reasons
status: todo
owners: ["llm"]
dependencies: ["S001"]
files:
  - Sources/InvariantSwift/Core/Property.swift
---

## Options
A) Upgrade predicate to `(T) async throws -> Bool` and implement error capture + timeout.
B) Keep `(T) -> Bool` for MVP and remove `threwError/timedOut` from `FailureReason` until implemented.

## Acceptance criteria
- No dead/unreachable failure reason variants remain in public API.
