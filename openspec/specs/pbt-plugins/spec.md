# Capability: pbt-plugins

## Purpose
Define contracts for SwiftPM plugins and CLI tooling used by InvariantSwift.

## ADDED Requirements
### Requirement: No default network permissions
Plugins MUST NOT request network permissions by default.

#### Scenario: Minimal permissions
Given the package manifest defines a plugin
When permissions are declared
Then only required permissions (e.g., write to package directory) MUST be granted.

### Requirement: Stable CLI output format
CLI tools used by plugins MUST provide a stable output format suitable for machine parsing.

#### Scenario: JSON report
Given the CLI is invoked with `--format json`
When it completes
Then it MUST emit a JSON report with a documented schema.
