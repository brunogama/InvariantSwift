---
id: S001
title: Remove network permission from InvariantSwiftPlugin
epic: E005
priority: P0
status: done
dependencies: []
---

## Scope
- Remove `.allowNetworkConnections` from plugin permissions in `Package.swift`.

## Acceptance criteria
- `Package.swift` contains no network permission requests for `InvariantSwiftPlugin`.

## Files to touch
- `Package.swift`
