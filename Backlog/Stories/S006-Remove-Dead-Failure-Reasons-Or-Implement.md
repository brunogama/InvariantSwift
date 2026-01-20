---
id: S006
epic: E001
status: todo
owner: llm
depends_on: [S002]
---

# S006: Make failure reasons consistent with implemented behavior

## Problem
`FailureReason` includes cases that are unreachable or unimplemented.

## Scope
Either:
- implement timeouts and error propagation fully, or
- remove/mark as internal/experimental until implemented.

## Acceptance criteria
- Every public `FailureReason` case is reachable via a test, OR clearly marked experimental with no public exposure.
