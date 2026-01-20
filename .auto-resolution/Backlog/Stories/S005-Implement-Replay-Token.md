---
id: S005
epic: E001
status: done
owner: llm
depends_on: [S003]
---

# S005: Implement replay token

## Problem
Failures need a copy/paste token to reproduce deterministically.

## Scope
- Define `ReplayToken` type.
- Print it on failures.
- Provide `run(replay:)` entrypoint.

## Acceptance criteria
- A failed run returns a token that reproduces the same failing counterexample.
- Token round-trips through encode/decode.
- Tests prove token reproduction is stable.

## Files
- `Sources/InvariantSwift/Core/*`
- Tests.
