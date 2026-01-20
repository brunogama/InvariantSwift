# Delta for Plugins

## MODIFIED Requirements

### Requirement: Minimal Plugin Permissions
Plugins MUST request only the minimal permissions required to perform their work and MUST NOT request network permissions unless the feature is explicitly opt-in.

#### Scenario: Default build has no network permissions
- GIVEN the default package configuration
- WHEN building or running the plugins
- THEN no plugin requests network access
