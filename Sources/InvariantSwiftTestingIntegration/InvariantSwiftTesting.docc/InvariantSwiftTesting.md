# ``InvariantSwiftTesting``

Property-based testing integrated directly into Apple's `Testing` framework.

## Overview

`InvariantSwiftTesting` is the high-level runtime module for writing InvariantSwift properties as native Swift Testing tests.

Import this module when you want:

- `checkProperty` and `checkPropertyAsync`
- attachment-backed failure reporting
- property execution context inside helpers
- Swift Testing traits, attachments, and replay helpers around property execution

Add `InvariantSwiftMacroAPI` alongside `InvariantSwiftTesting` when you want macro declarations such as `@PropertyTest`, `@AsyncPropertyTest`, `@Regression`, `@Idempotent`, `@Deterministic`, or `@Pure`.

If you only need generators, shrinking, and the core property runner without Swift Testing-specific behavior, use `InvariantSwift` instead.

## Topics

### Essentials

- <doc:SwiftTestingIntegration>
- <doc:InvariantSwiftTestingTutorials>

### Manual Execution

- ``checkProperty(_:config:file:line:)``
- ``checkPropertyAsync(_:config:file:line:)``

### Runtime Integration

- ``PropertyTestContext``
- ``InvariantSwiftTestingTags``
- ``FailurePersistenceManager/loadReplayFailures(forTest:maxExamples:)``
- ``executePersistedFailureReplay(_:baseConfig:persistedFailure:testName:labels:file:line:)``
- ``executePersistedFailureReplayAsync(_:baseConfig:persistedFailure:testName:labels:timeoutSeconds:file:line:)``

### Specialized Macros

- <doc:SpecializedMacroUseCases>
- <doc:ChoosingAssertionMacros>
- <doc:SpecializedMacroTutorials>
