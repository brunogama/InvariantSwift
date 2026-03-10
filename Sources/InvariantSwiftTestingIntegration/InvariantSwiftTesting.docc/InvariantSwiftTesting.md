# ``InvariantSwiftTesting``

Property-based testing integrated directly into Apple's `Testing` framework.

## Overview

`InvariantSwiftTesting` is the high-level module for writing InvariantSwift properties as native Swift Testing tests.

Import this module when you want:

- `@PropertyTest` and `@AsyncPropertyTest`
- `@Regression` replay and persisted-failure workflows
- `checkProperty` and `checkPropertyAsync`
- attachment-backed failure reporting
- property execution context inside helpers

If you only need generators, shrinking, and the core property runner without Swift Testing-specific behavior, use `InvariantSwift` instead.

## Topics

### Essentials

- <doc:SwiftTestingIntegration>
- <doc:InvariantSwiftTestingTutorials>
- ``PropertyTest``
- ``AsyncPropertyTest``
- ``Regression``

### Manual Execution

- ``checkProperty(_:config:file:line:)``
- ``checkPropertyAsync(_:config:file:line:)``

### Runtime Integration

- ``PropertyTestContext``
- ``InvariantSwiftTestingTags``
- ``FailurePersistenceManager/loadReplayFailures(forTest:maxExamples:)``
- ``executePersistedFailureReplay(_:baseConfig:persistedFailure:testName:labels:file:line:)``
- ``executePersistedFailureReplayAsync(_:baseConfig:persistedFailure:testName:labels:timeoutSeconds:file:line:)``
