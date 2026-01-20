# Proposal: Codify minimal plugin permissions policy

## Summary
Codify and enforce a minimal-permissions policy for SwiftPM plugins used by InvariantSwift. The current manifest already avoids network permissions; this change adds guardrails so it stays that way.

## Background
SwiftPM plugin permissions are easy to expand accidentally during experimentation. For a testing framework, unexpected permissions (especially network) harm trust. This change adds documentation and optional CI validation.

## Goals
- Keep plugins at `writeToPackageDirectory` only (or less) by default.
- Add an explicit, documented opt-in mechanism if networking is ever needed.
- Add repo hygiene to avoid committing OS metadata.

## Non-Goals
- Implementing any network-enabled feature.
