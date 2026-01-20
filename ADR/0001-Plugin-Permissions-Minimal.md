# ADR 0001: Minimal plugin permissions

## Status
Accepted

## Context
The `InvariantSwiftPlugin` previously requested network permissions despite not implementing any network behavior. This introduces needless trust and security concerns for users.

## Decision
- Remove network permissions from the plugin by default.
- If networking is introduced later, it must be:
  - explicit opt-in (e.g., `--upload`)
  - documented, with clear data handling details

## Consequences
- Safer default behavior.
- Clearer permission story for OSS consumers.
