---
id: S007
epic: E005
priority: P0
title: Remove network permission from SwiftPM plugin and document opt-in approach
status: todo
owners: ["llm"]
dependencies: []
files:
  - Package.swift
  - Docs/RebuildPlan/06-Plugin-Permissions.md
  - Plugins/InvariantSwiftPlugin/**
---

## Acceptance criteria
- `Package.swift` has no `.allowNetworkConnections` for the plugin.
- Plugin continues to run local CLI and generate local artifacts.
