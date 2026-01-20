# Capability: pbt-core

## ADDED Requirements
### Requirement: Core is dependency-minimal
The core product MUST NOT depend on macro toolchains (SwiftSyntax) or optional heavy dependencies.

#### Scenario: Core import is lightweight
Given a project imports only the core product
When resolving dependencies
Then macro toolchain dependencies MUST NOT be included.
