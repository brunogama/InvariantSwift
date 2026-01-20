# Delta for Swift Testing Integration

## MODIFIED Requirements

### Requirement: Async properties are supported
The integration MUST support async properties and propagate errors.

#### Scenario: Async property failure
- GIVEN an async property
- WHEN it fails
- THEN the failure MUST be reported with the same reproduction info as sync properties
