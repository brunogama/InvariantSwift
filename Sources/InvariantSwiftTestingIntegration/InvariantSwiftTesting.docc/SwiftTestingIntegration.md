@Metadata {
  @PageKind(article)
}

# Swift Testing Integration

Use `InvariantSwiftTesting` when you want property tests to participate in Swift Testing's traits, issues, attachments, and parameterized-case model.

## Overview

`InvariantSwiftTesting` layers InvariantSwift's generators, shrinking, and replay support onto Apple's `Testing` framework.

The integration gives you three main entry points:

- ``PropertyTest`` for synchronous macro-generated property tests
- ``AsyncPropertyTest`` for async or scheduler-driven properties
- ``checkProperty(_:config:file:line:)`` and ``checkPropertyAsync(_:config:file:line:)`` when you want to construct a ``Property`` manually inside a `@Test`

## Macro-Generated Tests

``PropertyTest`` and ``AsyncPropertyTest`` expand to Swift Testing `@Test` wrappers.

They automatically:

- infer or build generators from the function parameters
- run the property with deterministic seeding when configured
- shrink failures to a minimal counterexample
- record failures through Swift Testing's issue system
- attach execution artifacts for local debugging and CI

Example:

```swift
import InvariantSwiftTesting
import Testing

@PropertyTest(
  iterations: 200,
  seed: 42,
  timeLimit: .minutes(1)
)
func additionIsCommutative(a: Int, b: Int) {
  #expect(a + b == b + a)
}
```

## Forwarded Swift Testing Traits

The generated wrappers can forward native Swift Testing traits directly from the property macro declaration.

Supported forwarded traits:

- `tags`
- `bugs`
- `serialized`
- `timeLimit`
- `enabledIf`
- `disabledReason`

Example:

```swift
import InvariantSwiftTesting
import Testing

extension Tag {
  @Tag static var regression: Self
}

@PropertyTest(
  iterations: 100,
  tags: [.regression],
  bugs: [Bug.bug(id: "PBT-123")],
  serialized: true
)
func parserProperty(input: String) {
  #expect(!input.isEmpty || input.isEmpty)
}
```

Generated property tests also apply:

- ``InvariantSwiftPropertyExecutionTrait``
- ``InvariantSwiftTestingTags/propertyBased``

Replay-only generated cases apply:

- ``InvariantSwiftTestingTags/propertyReplay``

## Failure Reporting and Attachments

Property failures are reported as Swift Testing issues and produce attachments instead of embedding all execution detail in a single message.

Common attachments:

- `property-run.json`
- `counterexample.txt`
- `shrunk-counterexample.txt`
- `classification.txt` when classification output exists

Replay verification failures may also add:

- `expected-counterexample.txt`
- `actual-counterexample.txt`

The `property-run.json` attachment captures execution metadata such as test name, seed, iteration count, failure reason, labels, and replay identifiers.

To preserve attachments from `swift test`, pass an attachments directory:

```bash
swift test --attachments-path .build/test-attachments
```

## Replay and Regression Workflows

``Regression`` persists failures and can replay them on later runs.

Example:

```swift
import InvariantSwiftTesting
import Testing

@PropertyTest
@Regression(replayFirst: true, maxExamples: 10, exposeCasesAsTests: true)
func parserNeverCrashes(input: String) {
  _ = input.utf8.map { $0 }
  #expect(true)
}
```

This enables two complementary flows:

- replay persisted failures before random generation
- expose persisted failures as parameterized Swift Testing cases when `exposeCasesAsTests` is enabled

For custom replay harnesses, use:

- ``FailurePersistenceManager/loadReplayFailures(forTest:maxExamples:)``
- ``executePersistedFailureReplay(_:baseConfig:persistedFailure:testName:labels:file:line:)``
- ``executePersistedFailureReplayAsync(_:baseConfig:persistedFailure:testName:labels:timeoutSeconds:file:line:)``

## Property Execution Context

``PropertyTestContext`` exposes the currently running property through a task-local value.

The context includes:

- `testName`
- `seed`
- `config`
- `labels`
- `isReplay`
- `replayFailureID`

This is useful in helper APIs that need to inspect the active property run without taking extra plumbing parameters.

## Choosing an Entry Point

Use this rule of thumb:

- choose ``PropertyTest`` for standard synchronous property functions
- choose ``AsyncPropertyTest`` for async properties or scheduler-driven interleaving checks
- choose ``checkProperty(_:config:file:line:)`` or ``checkPropertyAsync(_:config:file:line:)`` when you need to build the property manually inside a `@Test`
- add ``Regression`` when you want failures to persist across runs and CI
