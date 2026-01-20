# ADR-0001: Plugin network permissions

## Status
Accepted

## Context
The SwiftPM plugin declared network access with the reason "Upload telemetry and coverage data".
The implementation currently runs local tools and writes local artifacts.

## Decision
Remove network permissions by default. Any future upload capability must be explicit opt-in and tightly scoped.

## Consequences
- Higher trust and adoption.
- Upload features require additional design and documentation.
