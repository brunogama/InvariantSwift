# Plugins Specification

## Purpose

Document SwiftPM plugin behavior and required permissions for InvariantSwift tooling.

---

## Requirements

### Requirement: Minimal Plugin Permissions

Plugins MUST request only the minimal permissions required to perform their work.

#### Scenario: Plugins request no network permissions

- GIVEN the current `Package.swift`
- WHEN inspecting plugin permissions
- THEN neither plugin requests network access

### Requirement: Deterministic Outputs

Plugin-generated files MUST be deterministic given the same inputs.

#### Scenario: Ghostwriter produces stable snapshots

- GIVEN a stable set of input types
- WHEN running Ghostwriter twice
- THEN the generated files are byte-identical

### Requirement: Plugins Are Optional

Core library functionality MUST NOT require plugins.

#### Scenario: Tests run without plugin invocation

- GIVEN the core library
- WHEN running `swift test`
- THEN no plugin execution is required

---

## Plugin Catalog

| Plugin | Verb | Purpose | Permissions |
|--------|------|---------|-------------|
| `InvariantSwiftPlugin` | `invariant` | Run property tests with advanced features | `writeToPackageDirectory` |
| `GhostwriterPlugin` | `ghostwrite` | Generate property tests from source | `writeToPackageDirectory` |

---

## Notes

- Both plugins request `writeToPackageDirectory` only
- If a future feature requires network access, it MUST be explicitly opt-in and documented
- Plugins depend on their respective CLI executables (`FuncTestCLI`, `GhostwriterCLI`)
