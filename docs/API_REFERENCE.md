# API Reference

Complete reference for all public types in InvariantSwift.

---

## Table of Contents

1. [Core Types](#core-types)
   - [Gen\<T\>](#gent)
   - [Size](#size)
   - [Shrink\<T\>](#shrinkt)
   - [Property\<T\>](#propertyt)
   - [PropertyResult\<T\>](#propertyresultt)
   - [PropertyConfig](#propertyconfig)
   - [Seed](#seed)
2. [Generator Types](#generator-types)
   - [Primitive Generators](#primitive-generators)
   - [Collection Generators](#collection-generators)
   - [Optional and Result Generators](#optional-and-result-generators)
   - [Domain Generators](#domain-generators)
3. [Presentation](#presentation)
   - [PrettyPrinter](#prettyprinter)
   - [PrettyPrintable](#prettyprintable)
   - [DiffFormat](#diffformat)
   - [StructuredDiff](#structureddiff)
4. [Testing Integration](#testing-integration)
   - [checkProperty](#checkproperty)
   - [checkPropertyAsync](#checkpropertyasync)
   - [expectNoDifference](#expectnodifference)
   - [expectDifference](#expectdifference)
5. [Model-Based Testing](#model-based-testing)
   - [Command Protocol](#command-protocol)
   - [StateMachine Protocol](#statemachine-protocol)
   - [ModelTestConfig](#modeltestconfig)
   - [ModelTestResult](#modeltestresult)
6. [Advanced Types](#advanced-types)
   - [Lens\<Root, Value\>](#lensroot-value)
   - [Prism\<Root, Value\>](#prismroot-value)
   - [AsyncProperty](#asyncproperty)
   - [CoverageConfig](#coverageconfig)
7. [Macro Types](#macro-types)
   - [GeneratorExpression](#generatorexpression)
   - [ArbitraryShrinkStrategy](#arbitraryshrinkstrategy)

---

## Core Types

### Gen\<T\>

The fundamental generator type. Produces random values of type `T` with integrated shrinking.

```swift
public struct Gen<T>: @unchecked Sendable
```

#### Initializers

```swift
// Create a generator from a generate function
init(generate: @escaping (inout SeedBasedRandomNumberGenerator, Size) -> T)

// Create a generator with custom shrinking
init(
    generate: @escaping (inout SeedBasedRandomNumberGenerator, Size) -> T,
    shrink: Shrink<T>
)
```

#### Static Methods

| Method | Description |
|--------|-------------|
| `pure(_ value: T) -> Gen<T>` | Create a generator that always produces the same value |
| `oneOf(_ generators: [Gen<T>]) -> Gen<T>` | Choose randomly from multiple generators |
| `frequency(_ weighted: [(Int, Gen<T>)]) -> Gen<T>` | Choose with weighted probability |
| `zip<A, B>(_ a: Gen<A>, _ b: Gen<B>) -> Gen<(A, B)>` | Combine two generators into a tuple |
| `zip<A, B, C>(...)` | Combine 3+ generators |

#### Instance Methods

| Method | Description |
|--------|-------------|
| `map<U>(_ f: (T) -> U) -> Gen<U>` | Transform generated values |
| `flatMap<U>(_ f: (T) -> Gen<U>) -> Gen<U>` | Chain dependent generators |
| `suchThat(_ predicate: (T) -> Bool) -> Gen<T>` | Filter generated values |
| `withShrink(_ shrink: Shrink<T>) -> Gen<T>` | Add or replace shrinking strategy |
| `resize(_ newSize: Size) -> Gen<T>` | Override size for generation |
| `scale(_ factor: Double) -> Gen<T>` | Scale the size parameter |

#### Example

```swift
// Create a custom generator
let pointGen = Gen.zip(Gen<Int>.int, Gen<Int>.int)
    .map { Point(x: $0, y: $1) }
    .suchThat { $0.x >= 0 && $0.y >= 0 }

// Generate a value
var rng = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
let point = pointGen.generate(&rng, Size(value: 100))
```

---

### Size

Controls the complexity of generated values.

```swift
public struct Size: Sendable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `value` | `Int` | The raw size value (0-100 typical) |

#### Static Properties

| Property | Value | Description |
|----------|-------|-------------|
| `.zero` | 0 | Minimal size |
| `.small` | 10 | Small values |
| `.medium` | 50 | Medium complexity |
| `.large` | 100 | Large/complex values |
| `.max` | Int.max | Maximum size |

#### Methods

| Method | Description |
|--------|-------------|
| `scaled(by factor: Double) -> Size` | Scale size by factor |
| `clamped(to range: ClosedRange<Int>) -> Size` | Clamp to range |

---

### Shrink\<T\>

Defines how to shrink values toward simpler cases.

```swift
public struct Shrink<T>: @unchecked Sendable
```

#### Static Properties

| Property | Description |
|----------|-------------|
| `.empty` | No shrinking (returns empty sequence) |

#### Static Methods

| Method | Description |
|--------|-------------|
| `towards(_ target: T, _ value: T) -> [T]` | Shrink toward target value |
| `lazy(_ f: @escaping (T) -> AnySequence<T>) -> Shrink<T>` | Lazy shrink sequence |

#### Instance Methods

| Method | Description |
|--------|-------------|
| `shrink(_ value: T) -> AnySequence<T>` | Generate shrink candidates |
| `contramap<U>(_ f: @escaping (U) -> T) -> Shrink<U>` | Transform input type |
| `map<U>(_ f: @escaping (T) -> U) -> Shrink<U>` | Transform output type |

---

### Property\<T\>

Represents a testable property with generator and predicate.

```swift
public struct Property<T>: @unchecked Sendable
```

#### Initializers

```swift
// Basic property
init(generator: Gen<T>, predicate: @escaping (T) -> Bool)

// With assumption (precondition filter)
init(
    generator: Gen<T>,
    assumption: @escaping (T) -> Bool,
    predicate: @escaping (T) -> Bool
)

// Async predicate
init(generator: Gen<T>, predicate: @escaping (T) async -> Bool)
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `generator` | `Gen<T>` | Value generator |
| `predicate` | `(T) -> Bool` | Property assertion |
| `assumption` | `((T) -> Bool)?` | Optional precondition |

---

### PropertyResult\<T\>

The outcome of running a property test.

```swift
public enum PropertyResult<T>: Sendable where T: Sendable
```

#### Cases

| Case | Description |
|------|-------------|
| `.success(iterations: Int)` | All iterations passed |
| `.failure(counterexample: T, shrunk: T?, iterations: Int, seed: Seed)` | Found failing case |
| `.gaveUp(discarded: Int, iterations: Int)` | Too many discarded values |

#### Example

```swift
switch result {
case .success(let iterations):
    print("Passed \(iterations) iterations")
case .failure(let original, let shrunk, _, let seed):
    print("Failed with: \(shrunk ?? original)")
    print("Reproduce with seed: \(seed)")
case .gaveUp(let discarded, _):
    print("Gave up after \(discarded) discarded values")
}
```

---

### PropertyConfig

Configuration options for property testing.

```swift
public struct PropertyConfig: Sendable
```

#### Initializers

```swift
init(
    iterations: Int = 100,
    maxShrinks: Int = 1000,
    maxSize: Int = 100,
    timeout: TimeInterval? = nil,
    seed: Seed? = nil,
    enableCoverage: Bool = false,
    coverageStrategy: CoverageStrategy = .adaptive
)
```

#### Static Properties

| Property | Description |
|----------|-------------|
| `.default` | 100 iterations, 1000 shrinks, no timeout |
| `.quick` | 10 iterations, for fast checks |
| `.thorough` | 1000 iterations, for critical code |

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `iterations` | `Int` | 100 | Test cases to run |
| `maxShrinks` | `Int` | 1000 | Maximum shrink attempts |
| `maxSize` | `Int` | 100 | Maximum generator size |
| `timeout` | `TimeInterval?` | nil | Per-property timeout |
| `seed` | `Seed?` | nil | Reproducible seed |
| `enableCoverage` | `Bool` | false | Track coverage |

---

### Seed

Deterministic seed for reproducible generation.

```swift
public struct Seed: Sendable, Hashable
```

#### Initializers

```swift
init(value: UInt64)
```

#### Static Properties

| Property | Description |
|----------|-------------|
| `.random` | Generate from system entropy |
| `.test` | Standard test seed (42) |
| `.zero` | Zero seed (auto-converts to 1) |
| `.max` | Maximum value (UInt64.max) |

#### Methods

| Method | Description |
|--------|-------------|
| `split() -> (Seed, Seed)` | Create two independent seeds |

---

## Generator Types

### Primitive Generators

Available as static properties/methods on `Gen`.

| Generator | Type | Description |
|-----------|------|-------------|
| `Gen<Int>.int` | `Gen<Int>` | Any Int |
| `Gen<Int>.int(in: Range)` | `Gen<Int>` | Int in range |
| `Gen<Int>.positive` | `Gen<Int>` | Positive integers (> 0) |
| `Gen<Int>.negative` | `Gen<Int>` | Negative integers (< 0) |
| `Gen<Double>.double` | `Gen<Double>` | Any Double |
| `Gen<Double>.double(in: Range)` | `Gen<Double>` | Double in range |
| `Gen<Bool>.bool` | `Gen<Bool>` | true or false |
| `Gen<String>.string` | `Gen<String>` | Arbitrary string |
| `Gen<String>.alphanumeric` | `Gen<String>` | Letters and digits |
| `Gen<String>.ascii` | `Gen<String>` | ASCII characters |
| `Gen<Character>.letter` | `Gen<Character>` | a-z, A-Z |
| `Gen<Character>.digit` | `Gen<Character>` | 0-9 |

### Collection Generators

| Generator | Type | Description |
|-----------|------|-------------|
| `Gen.array(_ element: Gen<T>)` | `Gen<[T]>` | Array of elements |
| `Gen.array(_ element: Gen<T>, count: Int)` | `Gen<[T]>` | Fixed-size array |
| `Gen.array(_ element: Gen<T>, count: Range)` | `Gen<[T]>` | Array with size in range |
| `Gen.set(_ element: Gen<T>)` | `Gen<Set<T>>` | Set of unique elements |
| `Gen.dictionary(_ keys: Gen<K>, _ values: Gen<V>)` | `Gen<[K: V]>` | Dictionary |

### Optional and Result Generators

```swift
// Optional
Gen.optional(Gen<Int>.int)                        // Int?
Gen.optional(Gen<Int>.int, nilProbability: 0.3)   // 30% nil

// Result
Gen.result(
    success: Gen<String>.string,
    failure: Gen<TestError>.error
)  // Result<String, TestError>
```

### Domain Generators

| Generator | Type | Description |
|-----------|------|-------------|
| `Gen<UUID>.uuid` | `Gen<UUID>` | Random UUID |
| `Gen.email` | `Gen<String>` | Email-like string |
| `Gen.url` | `Gen<URL>` | Valid URL |
| `Gen.port` | `Gen<Int>` | TCP/UDP port (1-65535) |
| `Gen.percentage` | `Gen<Int>` | 0-100 |
| `Gen.probability` | `Gen<Double>` | 0.0-1.0 |

---

## Presentation

### PrettyPrinter

Formats values and diffs for readable output.

```swift
public struct PrettyPrinter: Sendable
```

#### Static Methods

| Method | Description |
|--------|-------------|
| `format<T: PrettyPrintable>(_ value: T) -> String` | Format a value |
| `format(_ value: Any) -> String` | Format any value using reflection |
| `diff<T: Equatable>(_ lhs: T, _ rhs: T) -> String?` | Compute diff string |
| `diffAny(_ lhs: Any, _ rhs: Any) -> String?` | Diff any Equatable values |

### PrettyPrintable

Protocol for custom pretty-printing.

```swift
public protocol PrettyPrintable {
    func prettyPrint(config: PrettyConfig) -> String
}
```

Default conformances: `Int`, `String`, `Bool`, `Double`, `Array`, `Dictionary`, `Optional`, `Set`

### DiffFormat

Controls diff output formatting.

```swift
public struct DiffFormat: Sendable, Equatable
```

#### Static Properties

| Property | Removed | Inserted | Unchanged |
|----------|---------|----------|-----------|
| `.default` | `-` | `+` | ` ` |
| `.proportional` | `−` | `+` | ` ` (Unicode) |

### StructuredDiff

Represents differences between values.

```swift
public enum StructuredDiff: Sendable
```

#### Cases

| Case | Description |
|------|-------------|
| `.same(String)` | Unchanged content |
| `.removed(String)` | Content in first only |
| `.inserted(String)` | Content in second only |
| `.modified(String, String)` | Changed content |
| `.collapsed(unchangedCount: Int)` | Hidden unchanged items |

---

## Testing Integration

### checkProperty

Run a property test synchronously.

```swift
public func checkProperty<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = .default
) throws
```

### checkPropertyAsync

Run a property test asynchronously.

```swift
public func checkPropertyAsync<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = .default
) async throws
```

### expectNoDifference

Assert equality with detailed diff output.

```swift
public func expectNoDifference<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: @autoclosure () -> String = "",
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
)
```

### expectDifference

Assert a value changes as expected.

```swift
public func expectDifference<T: Equatable>(
    _ value: T,
    _ operation: () throws -> Void,
    changes: (inout T) -> Void,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) rethrows
```

#### Async Version

```swift
public func expectDifference<T: Equatable & Sendable>(
    _ value: T,
    _ operation: () async throws -> Void,
    changes: (inout T) -> Void
) async rethrows
```

---

## Model-Based Testing

### Command Protocol

Base protocol for state machine commands.

```swift
public protocol Command: Sendable {
    associatedtype Model
    associatedtype Result: Sendable
    
    func run(model: inout Model) -> Result
    func postcondition(model: Model, result: Result) -> Bool
}
```

### StateMachine Protocol

Protocol for defining testable state machines.

```swift
public protocol StateMachine: Sendable {
    associatedtype CommandType: Command where CommandType.Model == Self
    
    static var initialState: Self { get }
    static var commandGenerator: Gen<CommandType> { get }
}
```

### ModelTestConfig

Configuration for model-based tests.

```swift
public struct ModelTestConfig: Sendable {
    let maxCommands: Int
    let iterations: Int
    let seed: Seed?
}
```

### ModelTestResult

Result of model-based test execution.

```swift
public enum ModelTestResult<CommandType>: Sendable where CommandType: Command & Sendable
```

#### Cases

| Case | Description |
|------|-------------|
| `.success(iterations: Int)` | All sequences passed |
| `.failure(commands: [CommandType], step: Int)` | Failed at step |
| `.gaveUp(reason: String)` | Could not complete |

---

## Advanced Types

### Lens\<Root, Value\>

Functional optic for focusing on a value within a structure.

```swift
public struct Lens<Root, Value>: Sendable
```

#### Initializers

```swift
init(
    get: @escaping (Root) -> Value,
    set: @escaping (Value, Root) -> Root
)
```

#### Methods

| Method | Description |
|--------|-------------|
| `view(_ root: Root) -> Value` | Extract focused value |
| `set(_ value: Value, _ root: Root) -> Root` | Update focused value |
| `over(_ f: (Value) -> Value) -> (Root) -> Root` | Apply transformation |
| `compose<NewValue>(_ other: Lens<Value, NewValue>) -> Lens<Root, NewValue>` | Compose lenses |

### Prism\<Root, Value\>

Optic for sum types (Optional, enums).

```swift
public struct Prism<Root, Value>: Sendable
```

#### Methods

| Method | Description |
|--------|-------------|
| `preview(_ root: Root) -> Value?` | Extract if present |
| `review(_ value: Value) -> Root` | Construct root from value |

### AsyncProperty

Property with async predicate support.

```swift
public struct AsyncProperty<T>: Sendable where T: Sendable
```

### CoverageConfig

Configuration for coverage-guided testing.

```swift
public struct CoverageConfig: Sendable {
    let strategy: CoverageStrategy
    let targetCoverage: Double
    let maxIterations: Int
}
```

#### CoverageStrategy

```swift
public enum CoverageStrategy {
    case uniform      // Equal probability for all branches
    case adaptive     // Prioritize uncovered branches
    case focused      // Focus on specific branches
}
```

---

## Macro Types

### GeneratorExpression

Expression type for the `@Gen` macro.

```swift
public struct GeneratorExpression: ExpressibleByNilLiteral, Sendable
```

Used internally by macros to specify generator overrides.

### ArbitraryShrinkStrategy

Shrinking strategy for `@Arbitrary` macro.

```swift
public enum ArbitraryShrinkStrategy: Sendable {
    case none           // No shrinking
    case structural     // Shrink each field independently
    case recursive      // Full recursive shrinking
}
```

---

## Error Types

### BusinessRuleViolation

Error thrown when a business rule is violated.

```swift
public struct BusinessRuleViolation: Error, CustomStringConvertible, Sendable
```

### BusinessRuleGaveUp

Error thrown when generation cannot satisfy constraints.

```swift
public struct BusinessRuleGaveUp: Error, CustomStringConvertible, Sendable
```

---

## Operators

### Function Composition

| Operator | Description | Example |
|----------|-------------|---------|
| `>>>` | Left-to-right composition | `f >>> g` (apply f then g) |
| `\|>` | Pipe operator | `value \|> f \|> g` |

### Lens Composition

| Operator | Description |
|----------|-------------|
| `>>>` | Compose two lenses |

---

## See Also

- [Generators Guide](GENERATORS.md) - Comprehensive generator documentation
- [Shrinking Guide](SHRINKING.md) - How shrinking works
- [Macros Guide](MACROS.md) - Macro system documentation
- [Advanced Features](ADVANCED.md) - Coverage, model-based, async testing
