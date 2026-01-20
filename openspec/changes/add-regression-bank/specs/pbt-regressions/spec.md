# Capability: pbt-regressions

## ADDED Requirements
### Requirement: Replay-first execution
When a regression bank is enabled, stored regressions MUST be executed before random generation.

#### Scenario: Regression runs first
Given a stored regression for a property and regression bank enabled
When the property is executed
Then the stored regression MUST run before any newly generated inputs.

### Requirement: Stable on-disk format
Regression records MUST be stored in a stable text format suitable for VCS or CI artifacts.

#### Scenario: JSON regression record
Given a regression is persisted
When the file is read later
Then it MUST parse successfully and allow replay of the failure.
