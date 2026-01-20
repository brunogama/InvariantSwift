# Plugins and Permissions

## Rule
The SPM plugin should request the minimum permissions required.

## Current action
- Network permission removed from `Package.swift` for `InvariantSwiftPlugin`.

## Future design
If telemetry or uploads exist:
- implement as an explicit CLI subcommand (`invariant upload ...`)
- request permission only when needed
- document what is sent, where, and how to disable
