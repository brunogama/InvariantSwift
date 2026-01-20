# Proposal: Add replay token (deterministic reproduction)

## Summary
Introduce a stable replay token that captures enough information to reproduce failures reliably: seed, size schedule, and shrink path (or an equivalent trace).

## Background
The repository includes a `ReproduceMacro`, but the runner does not guarantee that all required execution details are captured. Users need a copy/paste recipe to reproduce a CI failure locally.

## Goals
- A serializable replay token
- Runner support to run from token
- Failure output includes token

## Non-Goals
- Persistent regression banque (separate change)
