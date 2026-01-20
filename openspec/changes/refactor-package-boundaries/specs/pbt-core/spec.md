# Delta for PBT Core

## ADDED Requirements

### Requirement: Runtime target does not depend on SwiftSyntax
The core runtime package MUST NOT depend on SwiftSyntax or macro toolchain dependencies.

#### Scenario: Core builds without SwiftSyntax
- WHEN importing only the core product
- THEN SwiftSyntax MUST not be in the dependency graph
