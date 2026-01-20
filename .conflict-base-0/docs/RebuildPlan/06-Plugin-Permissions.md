# SwiftPM plugin permissions

## Goal
No default-on network permissions in an OSS testing tool.

## Plan

- Remove `.allowNetworkConnections` from the plugin unless and until there is a dedicated opt-in upload command.
- If upload is added later:
  - require explicit flag `--upload`
  - restrict scope to specific ports/domains
  - document what is uploaded

## Acceptance criteria

- `Package.swift` does not request network permissions for InvariantSwiftPlugin.
- Plugin still functions for local runs and report generation.
