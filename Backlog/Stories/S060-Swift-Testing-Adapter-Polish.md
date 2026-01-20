---
id: S060
title: Improve Swift Testing integration output and ergonomics
epic: E006
priority: P1
status: todo
dependencies: [S040]
---

## Scope
- Ensure failures show:
  - shrunk counterexample
  - replay token
  - reason + error if thrown

## Acceptance criteria
- Failure output is stable and actionable.

## Files to touch
- Swift Testing adapter sources (wherever implemented)
