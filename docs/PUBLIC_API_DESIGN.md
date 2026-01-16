# InvariantSwift Public API Design

**Document Purpose**: Define the stable, long-term public API surface for InvariantSwift 1.0

**Design Date**: January 16, 2026
**Based On**: API_AUDIT.md (Task 0.1)
**Target Release**: 1.0.0 (after Milestones 0-3)
**Status**: Design phase → Ready for team review

---

## Executive Summary

This document designs the production-ready public API for InvariantSwift by:

1. **Organizing** 82 public symbols into coherent namespaces
2. **Clarifying** protocol hierarchies and type relationships
3. **Standardizing** naming across the framework
4. **Stabilizing** the API surface for long-term compatibility
5. **Deprecating** legacy/duplicate APIs with clear migration paths

**Key Design Decisions**:
- ✅ Keep all core types stable (Gen, Property, PropertyRunner, Seed)
- ✅ Adopt semantic naming: `SeedBasedRandomNumberGenerator` (not "Seeded")
- 🗑️ Deprecate PropertyChecker (superseded by PropertyRunner)
- ✅ Organize into 4 coherent modules: Core, Generators, Advanced, Observability
- ✅ Emphasize functional composition (Lens, Prism, Traversal)
- ✅ Provide clear upgrade path from 0.x → 1.0

---

## 1. Namespace Organization

### High-Level Architecture

```
InvariantSwift (root module)
│
├── Core Module
│   ├── Generation (Gen, Size, Shrink, Seed)
│   ├── Properties (Property, PropertyResult, PropertyConfig)
│   ├── Execution (PropertyRunner)
│   └── Model-Based Testing (Command, StateMachine, ModelTestRunner)
│
├── Generators Module (Gen+ static properties and methods)
│   ├── Primitives (Gen.int, Gen.string, Gen.bool, etc.)
│   ├── Collections (Gen.array, Gen.set, Gen.dictionary)
│   ├── Optional & Result (Gen.optional, Gen.result)
│   ├── Domain-Specific (Gen.uuid, Gen.email, Gen.port)
│   └── Combinators (Gen.oneOf, Gen.frequency, Gen.suchThat)
│
├── Advanced Module
│   ├── Functional Programming (Lens, Prism, Traversal, compose/pipe)
│   ├── Coverage-Guided Testing (CoverageCollector, CoverageStrategy, CoverageReport)
│   ├── Async Properties (AsyncProperty, PropertyEffect, PropertyEffectExecutor)
│   ├── Specialized Testing (Linearizability, DICE, Metamorphic)
│   └── Invariant Mining (InvariantMining)
│
└── Observability Module
    ├── Telemetry (TelemetrySystem)
    ├── Reliability (FlakeHunter)
    ├── Presentation (prettyPrint)
    └── Examples (ExampleDatabase)
```

### Module Import Strategy

**For Most Users**:
```swift
import InvariantSwift

// Direct access to all core APIs
let gen: Gen<Int> = Gen.int
let property = Property(generator: gen, predicate: { $0 >= 0 })
let runner = PropertyRunner()
```

**For Advanced Users**:
```swift
import InvariantSwift
import InvariantSwift.Advanced

// Access to lenses, advanced coverage features, etc.
let lens = Lens<PropertyConfig, Int>(...)
let collector = CoverageCollector()
```

**For Macro Users** (Milestone 3):
```swift
import InvariantSwift
import InvariantSwiftMacros  // Separate package for macros

@PropertyTest
func testIntegerProperties(a: Int, b: Int) {
    #expect(a + b == b + a)  // Commutativity
}
```

---

## 2. Core API Design

### 2.1 Generation Hierarchy

```
Seed (deterministic RNG seed)
  │
  ├─ Seed.init(value: UInt64)
  ├─ Seed.random (system entropy)
  ├─ Seed.split() → Seed (independent seed)
  └─ Seed.next() → (UInt64, Seed)

  │
  └─→ SeedBasedRandomNumberGenerator
      │ (implements RandomNumberGenerator protocol)
      │
      └─→ Gen<T> (protocol witness)
          │
          ├─ Functor instance (map:)
          ├─ Applicative instance (pure:, apply:, zip:)
          └─ Monad instance (flatMap:)
```

**Mathematical Foundation**:
```
Gen<T> ≅ (Seed, Size) → (T, Shrink<T>)

Where:
- Seed: 64-bit deterministic pseudorandom state
- Size: Complexity parameter (0-100)
- T: Generated value
- Shrink<T>: Reduction strategy for failed values
```

### 2.2 Property Definition Hierarchy

```
Property<T>
  │
  ├─ Property.init(generator:, predicate:)
  │   └─ Basic property (no assumptions)
  │
  ├─ Property.init(generator:, assumption:, predicate:)
  │   └─ Property with precondition filtering
  │
  └─ PropertyResult<T> (execution outcome)
      ├─ .success(iterations: Int)
      ├─ .failure(counterexample: T, iterations: Int, shrunk: T)
      └─ .gaveUp(discarded: Int, iterations: Int)
```

### 2.3 PropertyRunner (Execution Engine)

```
PropertyRunner (actor)
  │
  ├─ init(seed: Seed?)
  │   └─ Creates deterministic or random RNG
  │
  ├─ runProperty<T>(_ property: Property<T>,
  │                 config: PropertyConfig = .default)
  │   → PropertyResult<T>
  │
  ├─ async runPropertyWithCoverageTracking<T>(
  │           _ property: Property<T>,
  │           knownSymbols: [String])
  │   → (PropertyResult<T>, CoverageReport)
  │
  └─ async runPropertyWithCoverageGuidance<T>(
             _ property: Property<T>,
             collector: CoverageCollector,
             coverageStrategy: CoverageStrategy)
      → (PropertyResult<T>, CoverageReport)
```

### 2.4 Model-Based Testing Hierarchy

```
Command (protocol)
  │
  ├─ Associated Types:
  │  ├─ State (model state type)
  │  └─ Env (system under test)
  │
  ├─ Methods:
  │  ├─ generate(in: State) → Command?
  │  ├─ precondition(_ state: State) → Bool
  │  ├─ execute(on: inout Env) → String
  │  └─ postcondition(_ state: State, _ env: Env) → Bool
  │
  └─ Used by: StateMachine, ModelTestRunner
```

---

## 3. Generator Design

### 3.1 Generator Categories

#### Primitive Generators (Core Types)
```swift
public extension Gen {
  // Numeric types
  static var int: Gen<Int>              // Full range
  static var positive: Gen<Int>         // > 0
  static var negative: Gen<Int>         // < 0
  static var double: Gen<Double>        // Includes NaN, Inf

  // Text types
  static var string: Gen<String>        // Any Unicode
  static var printableString: Gen<String>  // ASCII printable
  static var ascii: Gen<Character>      // ASCII charset

  // Boolean
  static var bool: Gen<Bool>            // true/false
}
```

#### Collection Generators
```swift
public extension Gen {
  // Fixed type, variable size
  static func array<T>(of: Gen<T>) -> Gen<[T]>
  static func set<T: Hashable>(of: Gen<T>) -> Gen<Set<T>>
  static func dictionary<K: Hashable, V>(
    keys: Gen<K>,
    values: Gen<V>
  ) -> Gen<[K: V]>

  // Fixed size variants
  static func array<T>(ofSize: Int, of: Gen<T>) -> Gen<[T]>
  static func set<T: Hashable>(ofSize: Int, of: Gen<T>) -> Gen<Set<T>>

  // Edge cases
  static var emptyCollection: Gen<[Int]>
  static func singletonCollection<T>() -> Gen<[T]>
}
```

#### Optional & Result
```swift
public extension Gen {
  // Optional: 50% nil, 50% Some(T)
  static func optional<T>(of: Gen<T>) -> Gen<T?>

  // Result: 50% success, 50% failure
  static func result<Success, Failure>(
    success: Gen<Success>,
    failure: Gen<Failure>
  ) -> Gen<Result<Success, Failure>>
}
```

#### Domain-Specific Generators
```swift
public extension Gen {
  // Network
  static var port: Gen<UInt16>          // 1-65535
  static var ipAddress: Gen<String>     // IPv4 format

  // Identifiers
  static var uuid: Gen<UUID>
  static var email: Gen<String>         // Pattern-based, not RFC-compliant

  // Quantities
  static var percentage: Gen<Int>       // 0-100
  static var probability: Gen<Double>   // 0.0-1.0
}
```

#### Combinators
```swift
public extension Gen {
  // Filtering
  func suchThat(_ predicate: @escaping (T) -> Bool) -> Gen<T>

  // Weighted selection
  static func oneOf<T>(_ options: [Gen<T>]) -> Gen<T>
  static func frequency<T>(_ options: [(weight: Int, gen: Gen<T>)]) -> Gen<T>

  // Numeric ranges
  func inRange(_ range: ClosedRange<T>) -> Gen<T> where T: Numeric & Comparable
  func between(_ min: T, _ max: T) -> Gen<T>

  // Biasing (coverage-guided)
  func biased(toward symbols: [String]) -> Gen<T>
}
```

### 3.2 Size Parameter

```swift
public struct Size: Sendable {
  public let value: Int  // 0-100 (complexity scale)

  public init(value: Int)

  // Convenience constants
  public static let small = Size(value: 10)
  public static let medium = Size(value: 50)
  public static let large = Size(value: 100)

  // Scaling
  public func scaled(by factor: Double) -> Self
}
```

**Usage Pattern**:
- **Size = 0**: Minimal values (empty collections, edge cases)
- **Size = 50**: Medium complexity
- **Size = 100**: Maximum complexity

**Generator Responsibility**:
- Collections: Size controls length (0→0 elements, 100→100+ elements)
- Strings: Size controls length
- Recursion: Size controls depth

---

## 4. Functional Programming Module

### 4.1 Optics (Lens, Prism, Traversal)

```swift
/// Lens: Focus on a single field in an immutable structure
public struct Lens<Root, Value> {
  public let view: (Root) -> Value
  public let set: (Value, Root) -> Root

  public func get(_ root: Root) -> Value
  public func set(_ value: Value, in root: Root) -> Root
  public func over(_ transform: @escaping (Value) -> Value) -> (Root) -> Root
  public func compose<Nested>(_ other: Lens<Value, Nested>) -> Lens<Root, Nested>
}

/// Prism: Focus on a case in a sum type (Optional, Result)
public struct Prism<Root, Value> {
  public let preview: (Root) -> Value?
  public let inject: (Value) -> Root
}

/// Traversal: Focus on multiple elements (for collections)
public struct Traversal<Root, Value> {
  // Applies a function to all focused values
}
```

### 4.2 Function Composition

```swift
// Composition operators
infix operator >>>  // Right-to-left: (a → b) >>> (b → c) = (a → c)
infix operator |>   // Left-to-right: a |> f |> g = g(f(a))

// Examples:
let addOne = { $0 + 1 }
let double = { $0 * 2 }

let composed1 = addOne >>> double  // (x+1)*2
let composed2 = addOne |> double   // double(addOne(x))

// Composition function
func compose<A, B, C>(_ f: @escaping (A) -> B, _ g: @escaping (B) -> C) -> (A) -> C {
  { x in g(f(x)) }
}
```

### 4.3 Higher-Order Functions

```swift
// Currying
public func curry<A, B, C>(_ f: @escaping (A, B) -> C) -> (A) -> (B) -> C

// Fixed-point combinator (Y combinator)
public func fix<T>(_ f: @escaping ((T) -> T) -> (T) -> T) -> (T) -> T

// Function manipulation
public func flip<A, B, C>(_ f: @escaping (A) -> (B) -> C) -> (B) -> (A) -> C
public func pipe<A, B>(_ value: A, _ f: @escaping (A) -> B) -> B

// Memoization, throttling, debouncing
public func memoize<A: Hashable, B>(_ f: @escaping (A) -> B) -> (A) -> B
public func throttle<A, B>(delay: Double, _ f: @escaping (A) -> B) -> (A) -> B
public func debounce<A, B>(delay: Double, _ f: @escaping (A) -> B) -> (A) -> B
```

---

## 5. Coverage-Guided Testing Module

### 5.1 Coverage Tracking

```swift
public actor CoverageCollector {
  // Register known code paths/symbols to track
  public func addKnownSymbols(_ symbols: [String]) async

  // Record when a symbol is executed
  public func recordCoverage(_ symbol: String) async

  // Get coverage report
  public var coverage: Double { get async }
  public var coveredPaths: Set<String> { get async }
}

public struct CoverageReport {
  public let coverage: Double              // 0.0-1.0
  public let coveredPaths: Set<String>
  public let uncoveredPaths: Set<String>
  public let executionCount: Int
  public let averageShrinks: Double
}
```

### 5.2 Coverage Strategies

```swift
public enum CoverageStrategy: Sendable {
  case uniform           // Generate uniformly (baseline)
  case adaptive         // Adapt based on coverage feedback
  case focused(on: Set<String>)  // Focus on specific symbols
  case weighted([String: Double])  // Custom weights per symbol
}

public struct CoverageConfig: Sendable {
  public let strategy: CoverageStrategy
  public let targetCoverage: Double      // 0.0-1.0 (e.g., 0.99)
  public let trackSymbols: [String]      // Symbols to track
  public let maxGenerations: Int
}
```

---

## 6. Async & Actor-Isolated Properties

### 6.1 Async Properties

```swift
public struct AsyncProperty<T> {
  public let generator: Gen<T>
  public let predicate: (T) async -> Bool

  public init(
    generator: Gen<T>,
    predicate: @escaping (T) async -> Bool
  )
}

// Usage:
let asyncProp = AsyncProperty(
  generator: Gen.string,
  predicate: { str in
    let result = await fetchData(str)
    return result.isValid
  }
)
```

### 6.2 Actor-Isolated Properties

```swift
public struct PropertyEffect<A> where A: Actor {
  // Property that runs on a specific actor (e.g., MainActor)
  public let generator: Gen<AnySendable>
  public let effect: (AnySendable) async -> Void
}

public extension PropertyRunner {
  @MainActor
  public func runPropertyOnMainActor<T>(
    _ property: AsyncProperty<T>,
    config: PropertyConfig = .default
  ) async -> PropertyResult<T>
}
```

---

## 7. Naming Conventions & Stability

### 7.1 API Naming Standards

| Category | Pattern | Example |
|----------|---------|---------|
| Static generators | `Gen.{typeName}` | `Gen.int`, `Gen.string`, `Gen.array` |
| Factory methods | `Gen.{adjective}()` | `Gen.optional()`, `Gen.result()` |
| Combinators | `gen.{verb}()` | `gen.map()`, `gen.flatMap()`, `gen.suchThat()` |
| Actors | `{Task}Runner` | `PropertyRunner`, `ModelTestRunner` |
| Configuration | `{Task}Config` | `PropertyConfig`, `ModelTestConfig` |
| Results | `{Task}Result<T>` | `PropertyResult<T>`, `ModelTestResult<T>` |
| RNG | `{Type}RandomNumberGenerator` | `SeedBasedRandomNumberGenerator` |

### 7.2 Breaking Changes (Execute in M0.5, Pre-1.0)

| Old Name | Action | Reason | Implementation |
|----------|--------|--------|-----------------|
| `SeededRandomNumberGenerator` | **RENAME** | Consistency with Seed type | Direct rename, no bridge |
| `PropertyChecker` | **DELETE** | Superseded by PropertyRunner | Remove entirely |
| `Gen.either()` | **DELETE** | Ambiguous naming | Remove or rename clearly |
| `●` operator | **DELETE** | Favor explicit `compose()` | Remove, use method instead |

**Why no deprecation?** Pre-1.0, zero public users, one-time breaking change acceptable.

### 7.3 Semantic Versioning Strategy

**Now (Pre-1.0, M0.5)**:
```
🔨 BREAK FREELY (one-time cleanup):
- SeededRandomNumberGenerator → SeedBasedRandomNumberGenerator (rename)
- PropertyChecker (delete)
- Gen.either() (delete/rename)
- ● operator (delete)

→ Clean slate for 1.0 release
```

**Once released as 1.0**:

```
✅ WILL NOT CHANGE (locked for major version):
- Gen<T> core API (generate, shrink)
- Property<T> definition
- PropertyRunner execution interface
- Seed type and methods
- PropertyConfig parameters
- All primitive generators (Gen.int, Gen.string, etc.)

✅ CAN ADD WITHOUT BREAKING (purely additive):
- New static generator properties (Gen.uuid, etc.)
- New Gen combinator methods
- New optional parameters with defaults
- New types in separate namespaces

❌ NO BREAKING CHANGES (until 2.0):
- Removing or renaming existing APIs forbidden
- Adding optional parameters only if default provided
- Behavior changes only if invisible to users
```

---

## 8. Deprecation & Migration Strategy

### 8.1 Breaking Changes Strategy (Pre-1.0)

**Since InvariantSwift is pre-1.0 and has NO public users**:
- ✅ **Break freely now** - no deprecation bridges needed
- ✅ **Rename directly** - no @available markers required
- ✅ **Remove unused APIs** - delete PropertyChecker entirely
- ✅ **Consolidate duplicates** - merge ExampleDatabase instances

**Breaking Changes to Execute in M0.5**:

```swift
// REMOVE (unused, superseded by PropertyRunner)
// ❌ PropertyChecker - DELETE entirely

// RENAME (consistency with Seed type naming)
// ❌ SeededRandomNumberGenerator
// ✅ SeedBasedRandomNumberGenerator

// REMOVE (ambiguous, low usage)
// ❌ Gen.either() - DELETE or rename to Gen.eitherOr()

// REMOVE (symbol preference over @available)
// ❌ ● operator - DELETE, use compose() method
// ✅ >>> and |> operators - KEEP (widely recognized)
```

**1.0.0 Release**:
- All breaking changes complete
- Clean, renamed API released
- Semantic versioning begins (1.0 → 1.x is safe, 1.x → 2.0 is breaking)

---

## 9. API Surface Stability Matrix

```
                    Likelihood of    Stability   Status
                    Future Change    Rating
────────────────────────────────────────────────────────
Gen<T>              Very Low         ⭐⭐⭐⭐⭐   LOCKED
Property<T>         Very Low         ⭐⭐⭐⭐⭐   LOCKED
PropertyRunner      Very Low         ⭐⭐⭐⭐⭐   LOCKED
Seed                Very Low         ⭐⭐⭐⭐⭐   LOCKED
PropertyConfig      Low              ⭐⭐⭐⭐    STABLE
Gen.{primitives}    Very Low         ⭐⭐⭐⭐⭐   LOCKED
Gen.array/set/dict  Very Low         ⭐⭐⭐⭐⭐   LOCKED
Lens/Prism/Traversal Low             ⭐⭐⭐⭐    STABLE
CoverageCollector   Medium           ⭐⭐⭐      BETA
AsyncProperty       Medium           ⭐⭐⭐      BETA
InvariantMining     High             ⭐⭐       EXPERIMENTAL
DICE                High             ⭐⭐       EXPERIMENTAL
────────────────────────────────────────────────────────
```

---

## 10. Public API Checklist for 1.0

### Core APIs (MUST be stable)
- [x] Gen<T> with Functor/Applicative/Monad instances
- [x] Property<T> and PropertyResult<T>
- [x] PropertyRunner (async actor)
- [x] Seed with determinism guarantees
- [x] Size parameter
- [x] PropertyConfig

### Generator Ecosystem (MUST be stable)
- [x] Primitive generators (int, string, bool, double)
- [x] Collection generators (array, set, dictionary)
- [x] Optional and Result generators
- [x] Generator combinators (map, flatMap, flatMap, etc.)
- [x] Domain-specific generators (uuid, email, port)

### Functional Programming (SHOULD be stable)
- [x] Lens, Prism, Traversal
- [x] Function composition (>>>, |>)
- [x] curry, compose, flip
- [x] Higher-order utilities (memoize, throttle, debounce)

### Advanced Features (NICE to have, OK if changes)
- [ ] Coverage-guided testing (still evolving)
- [ ] AsyncProperty (new pattern)
- [ ] PropertyEffect (actor integration)
- [ ] InvariantMining (experimental)
- [ ] DICE (experimental)

### Model-Based Testing (SHOULD be stable)
- [x] Command protocol
- [x] StateMachine protocol
- [x] ModelTestRunner
- [x] ModelTestResult<T>

### Observability (NICE to have)
- [x] TelemetrySystem
- [x] FlakeHunter
- [x] ExampleDatabase
- [x] prettyPrint()

---

## 11. Design Rationale

### Why This Organization?

**1. Functional Module Boundaries**
- **Core**: Essential types (Gen, Property, Runner)
- **Generators**: All ways to generate values
- **Advanced**: Sophisticated patterns (lenses, coverage)
- **Observability**: Debugging and metrics

→ **Benefit**: Users can import only what they need

**2. Protocol-Witness Pattern**
- `Gen<T>` as struct with `generate` and `shrink` fields
- Not a class hierarchy or enum
- Enables type-class-like behavior in Swift

→ **Benefit**: Composable, efficient, mathematically sound

**3. Naming Consistency**
- `{Task}Runner` for executors (PropertyRunner, ModelTestRunner)
- `{Task}Config` for configuration (PropertyConfig, ModelTestConfig)
- `{Task}Result<T>` for outcomes (PropertyResult, ModelTestResult)
- `Gen.{type}` for generators (Gen.int, Gen.string)

→ **Benefit**: Predictable API; users can guess names

**4. Operator Restraint**
- Only `>>>` and `|>` (widely recognized)
- Consider removing `●` for clarity
- Explicit method names available for all operations

→ **Benefit**: Balance between elegance and accessibility

**5. Backwards Compatibility Path**
- Deprecate → Bridge → Remove (3-phase)
- 2-release deprecation window (0.9 warning, 1.0 removal)
- Clear migration guide for each change

→ **Benefit**: User code doesn't break unexpectedly

---

## 12. Evolution & Future-Proofing

### Extension Points (Designed for Growth)

```swift
// New generators: Add as Gen.{name} static properties
public extension Gen {
  static var newType: Gen<NewType> { ... }  // No breaking change
}

// New combinators: Add as methods on Gen
public extension Gen {
  func newCombinator() -> Gen<U> { ... }  // Additive
}

// New execution models: Add new methods to PropertyRunner
public extension PropertyRunner {
  func runPropertyWithNewModel<T>(...) { ... }  // Additive
}

// New strategies: Add cases to enums
public enum CoverageStrategy {
  case .newStrategy  // No breaking change (non-exhaustive match OK)
}
```

### Invariants That MUST Hold

```
1. Gen<T> is always serializable (Seed + Size → T)
2. Same Seed + Size always produces same value (determinism)
3. Property test can always be reproduced with seed
4. Shrinking always produces "simpler" values
5. PropertyRunner is always actor-isolated
6. All public APIs are Sendable
```

---

## 13. Documentation Requirements

By 1.0.0 release, every public symbol must have:

```swift
/// One-line summary of what this does
///
/// Detailed explanation:
/// - Purpose and use case
/// - Mathematical background (if applicable)
/// - Invariants maintained
///
/// - Parameters:
///   - parameter1: What it does
///   - parameter2: Constraints
///
/// - Returns: Description of return value
///
/// - Example:
///   ```swift
///   let gen = Gen.int.map { $0 * 2 }
///   let value = gen.sample(size: .large, seed: .test)
///   ```
///
/// - Important: Any warnings or gotchas
///
/// - SeeAlso: Related types/functions
public func name(param: Type) -> ReturnType
```

---

## 14. API Design Approval Checklist

### Must Pass Before Proceeding to Task 0.3

- [ ] **Team consensus** on module organization
- [ ] **Naming** finalized (no more bikeshedding on "Seeded" vs "SeedBased")
- [ ] **Deprecation strategy** approved (PropertyChecker removal path clear)
- [ ] **Stability matrix** reflects realistic stability commitments
- [ ] **Extension points** identified and documented
- [ ] **Migration path** clear for all breaking changes
- [ ] **Version 1.0 gate** defined (what must be stable)

---

## 15. Related Documents & Next Steps

### Prerequisite Documents
- ✅ `API_AUDIT.md` (completed Task 0.1)

### Documents to Create
1. **`docs/API_DOCUMENTATION_TEMPLATE.md`** (Task 0.3)
   - Standard format for all public APIs
   - Required fields for DocC comments

2. **`docs/API_REFERENCE.md`** (Task 0.8)
   - Organized reference of all 82 public APIs
   - Quick lookup tables
   - Usage examples

3. **`docs/MIGRATION.md`** (Task 0.11)
   - Step-by-step upgrade from 0.x to 1.0
   - All name changes with before/after
   - Validation checklist

### Implementation Sequence
```
Task 0.2 (THIS): PUBLIC_API_DESIGN.md
    ↓
Task 0.3: API_DOCUMENTATION_TEMPLATE.md (what comment format to use)
    ↓
Task 0.4: Add DocC to all public symbols (implement the comments)
    ↓
Task 0.5: Rename APIs per this design (execute breaking changes)
    ↓
Task 0.6-0.8: Update reference docs
    ↓
Task 0.9-0.12: Validation & release
```

---

## 16. Approval & Sign-Off

**Document Status**: Ready for Design Review

**Questions for Team**:

1. **Namespace organization**: Are 4 modules (Core, Generators, Advanced, Observability) correct, or should we reorganize?

2. **PropertyChecker deprecation**: Agreed to remove in 1.0 with bridge in 0.9?

3. **Naming changes**:
   - SeededRNG → SeedBasedRNG ✓ (Yes?)
   - Gen.either() → clarify or keep? (?)
   - Operator ● → remove? (?)

4. **Stability commitments**: Are we comfortable locking Gen, Property, PropertyRunner, Seed for entire 1.x lifecycle?

5. **Future extensibility**: Do the extension points (new generators, new runners) support your use cases?

6. **Timeline**: Can we complete renames + documentation in M0 (40h budget)?

---

**Document Generated**: January 16, 2026
**Status**: DESIGN PHASE - Awaiting Team Review & Approval
**Next Action**: Present to team, gather feedback, finalize before Task 0.3

**Related Tasks**:
- 📋 **Previous**: Task 0.1 - API Audit ✅ Complete
- 📋 **Next**: Task 0.3 - API Documentation Template
- 📋 **Downstream**: Task 0.4-0.5 - Implementation of renames & documentation
