---
id: S001
title: Remove unjustified network permission from InvariantSwiftPlugin
epic: E005
priority: P0
status: done
dependencies: []
---

## Context
The SPM plugin requested `.allowNetworkConnections` despite not performing networking. This is a trust issue.

## Change
- Remove the network permission from `Package.swift` under the `InvariantSwiftPlugin` capability.

## Acceptance criteria
- `Package.swift` contains no `.allowNetworkConnections` for `InvariantSwiftPlugin`.
- `swift package plugin --list` still shows the plugin.

## Files touched
- `Package.swift`
