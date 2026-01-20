# Capability: pbt-replay

## Purpose
Define ReplayToken requirements and the rules for capturing/replaying failures deterministically.

## ADDED Requirements
### Requirement: Replay token captures sufficient state
A ReplayToken MUST contain enough information to reproduce:
- generation sequence for the failing iteration
- shrink search behavior that produced the minimal counterexample

#### Scenario: Replay reproduces minimal case
Given a failing run produces a minimal counterexample and a replay token
When replay is executed
Then the same minimal counterexample MUST be produced (or directly loaded) and fail again.

### Requirement: Replay token is stable text
ReplayToken MUST be representable as stable text (e.g., base64/JSON) suitable for logs and CI artifacts.

#### Scenario: CI log paste
Given a CI log containing a replay token
When a developer pastes it locally
Then the failure MUST reproduce.
