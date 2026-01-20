# Capability: pbt-generators

## ADDED Requirements
### Requirement: Domain generators are optional and modular
Domain generators MUST be provided in a separate product so core users do not pay dependency cost.

#### Scenario: Import core without domain generators
Given a project imports only the core product
When building
Then no domain-generator-only dependencies MUST be pulled in.

### Requirement: Domain generators are deterministic
Given a seed and config
When generating domain values
Then results MUST be deterministic and shrinkable.
