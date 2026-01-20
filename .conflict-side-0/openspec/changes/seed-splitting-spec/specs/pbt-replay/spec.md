# Spec Delta — pbt-replay

## ADDED Requirements

### Requirement: REPLAY-001 — Replay token determinism
The framework MUST emit a replay token that reproduces the same minimal counterexample deterministically.

#### Scenario: Token replays
- **Given:** a failing run that emits a token
- **When:** re-run using the token
- **Then:** the same minimal counterexample is produced

### Requirement: REPLAY-002 — Versioning
Replay tokens MUST include a version field and remain parseable across minor versions.

#### Scenario: Old token parses
- **Given:** a token from an older minor release
- **When:** decoded
- **Then:** it replays or reports an explicit unsupported-version error
