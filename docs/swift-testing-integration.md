# Swift Testing Integration

`InvariantSwiftTesting` is the user-facing module for running InvariantSwift properties inside Apple's `Testing` framework.

Use:

- `InvariantSwift` when you only need generators, shrinkers, and the core property runner.
- `InvariantSwiftTesting` when you want `@PropertyTest`, `@AsyncPropertyTest`, `@Regression`, `checkProperty`, Swift Testing traits, and attachment-backed failure reporting.

## Quick Start

Add the testing integration product to your test target:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "MyProject",
  dependencies: [
    .package(url: "https://github.com/your-org/InvariantSwift", from: "1.0.0")
  ],
  targets: [
    .testTarget(
      name: "MyProjectTests",
      dependencies: ["InvariantSwiftTesting"]
    )
  ]
)
```

Then import `Testing` and `InvariantSwiftTesting`:

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

If you want to build a property manually instead of using the macro:

```swift
import InvariantSwiftTesting
import Testing

@Test("sorting preserves count")
func sortingPreservesCount() async throws {
  let property = Property(generator: Gen<[Int]>.array(Gen<Int>.int)) { values in
    values.sorted().count == values.count
  }

  try await checkProperty(
    property,
    config: PropertyConfig(iterations: 200, seed: Seed(value: 42))
  )
}
```

## Macro Surface

### `@PropertyTest`

`@PropertyTest` generates a Swift Testing `@Test` wrapper around a synchronous property body. In addition to the existing property configuration, it now forwards native Swift Testing traits directly:

- `tags: [Tag]`
- `bugs: [Bug]`
- `serialized: Bool`
- `timeLimit: TimeLimitTrait.Duration?`
- `enabledIf: Bool?`
- `disabledReason: String?`

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
  serialized: true,
  enabledIf: true
)
func userRoundTrip(userID: Int) {
  #expect(userID == userID)
}
```

Notes:

- `enabledIf` and `disabledReason` are mutually exclusive.
- Generated property tests always include the `InvariantSwiftPropertyExecutionTrait`.
- Generated property tests automatically receive the `InvariantSwiftTestingTags.propertyBased` tag.

### `@AsyncPropertyTest`

Use `@AsyncPropertyTest` for async properties and scheduler-driven concurrent interleavings. It supports the same forwarded Swift Testing traits as `@PropertyTest`.

```swift
import InvariantSwiftTesting
import Testing

@available(macOS 15.0, *)
@AsyncPropertyTest(
  iterations: 25,
  timeLimit: .seconds(30)
)
func actorProperty(value: Int) async {
  #expect(value == value)
}
```

### `@Regression`

`@Regression` persists failing examples and replays them on later runs.

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

Behavior:

- Failed runs are persisted through the failure store.
- `replayFirst: true` replays stored failures before random generation.
- `exposeCasesAsTests: true` emits separate parameterized Swift Testing cases for stored failures.
- Replay cases are automatically tagged with `InvariantSwiftTestingTags.propertyReplay`.

## Tags and Context

`InvariantSwiftTesting` exposes a small public tag namespace for generated tests:

```swift
InvariantSwiftTestingTags.propertyBased
InvariantSwiftTestingTags.propertyReplay
```

Property execution state is also available through a task-local context:

```swift
import InvariantSwiftTesting

let context = PropertyTestContext.current
```

`PropertyTestContext.current` includes:

- `testName`
- `seed`
- `config`
- `labels`
- `isReplay`
- `replayFailureID`

This is intended for helper code that needs to inspect the current property execution without threading extra parameters through every assertion helper.

## Failure Reporting and Attachments

Property failures are recorded as Swift Testing issues and emit attachments instead of forcing all detail into a single long message.

Standard attachments:

- `property-run.json`
- `counterexample.txt`
- `shrunk-counterexample.txt`
- `classification.txt` when classification output exists

Replay verification failures may also emit:

- `expected-counterexample.txt`
- `actual-counterexample.txt`

`property-run.json` includes:

- `testName`
- `seed`
- `iterations`
- `outcome`
- `reason`
- `file`
- `line`
- `labels`
- `reproductionCommand`
- `replayFailureID`

To keep these artifacts from CI or local runs, pass an attachments path to Swift Testing:

```bash
swift test --attachments-path .build/test-attachments
```

## Replay Helpers

The integration layer also exposes helpers for custom replay flows:

- `FailurePersistenceManager.loadReplayFailures(forTest:maxExamples:)`
- `executePersistedFailureReplay(...)`
- `executePersistedFailureReplayAsync(...)`

These are useful when you want a custom test harness on top of the persisted-failure store rather than relying only on the generated `@Regression` wrappers.

## Choosing an Entry Point

Use this rule of thumb:

- Reach for `@PropertyTest` when a property can be expressed as a synchronous function over generated parameters.
- Reach for `@AsyncPropertyTest` when the property body is async or when scheduler-driven concurrency exploration matters.
- Reach for `checkProperty` or `checkPropertyAsync` when you want to build the `Property` manually inside a `@Test`.
- Add `@Regression` when you want failing examples to persist across runs and CI.
