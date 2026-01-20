# ADR-0001: Remove plugin network permission

## Status
Accepted

## Context
The SPM plugin requested network permission, but no networking is implemented by the plugin.

## Decision
Remove `.allowNetworkConnections(...)` from the plugin permissions.

## Consequences
- Improves OSS trust posture.
- Upload/telemetry (if desired) must be implemented explicitly and re-evaluated.
