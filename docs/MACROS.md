# InvariantSwift Macros Reference

InvariantSwift uses a powerful macro system to automate the generation of property-based tests, generators, and mathematical law verifications. This document provides a comprehensive reference for all available macros.

## Table of Contents

- [@Property](#property)
- [@Gen](#gen)
- [@Arbitrary](#arbitrary)
- [@Label](#label)
- [@BusinessRule](#businessrule)
- [@LawChecked](#lawchecked)
- [@DeriveGen](#derivegen)
- [@Equivalence](#equivalence)

---

## @Property

The `@Property` macro is the primary way to define property-based tests. It is attached to a function and generates a corresponding Swift Testing compatible test that executes the function with multiple generated inputs.

### Usage Syntax

```swift
@Property(
    iterations: Int = 100,
    seed: UInt64? = nil,
    maxShrinks: Int = 1000,
    verbose: Bool = false
)
func testFunctionName(param1: Type, param2: Type, ...) {
    // Test logic and assertions
}
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `iterations` | `Int` | `100` | The number of times to run the property test with different generated inputs. |
| `seed` | `UInt64?` | `nil` | An optional seed for deterministic random number generation. |
| `maxShrinks` | `Int` | `1000` | Maximum number of shrinking attempts to perform when a failure is found. |
| `verbose` | `Bool` | `false` | If true, provides detailed output during test execution. |

### Code Example

**Before Expansion:**

```swift
@Property(iterations: 50)
func testAdditionIsCommutative(a: Int, b: Int) {
    #expect(a + b == b + a)
}
```

**After Expansion (Simplified):**

```swift
@Test
func testAdditionIsCommutative_PropertyTest() throws {
    let generator = Gen.zip(Gen<Int>.int, Gen<Int>.int)
    let property = Property(generator: generator) { a, b in
        testAdditionIsCommutative(a: a, b: b)
        return true
    }
    let config = PropertyConfig(iterations: 50, maxShrinks: 1000)
    let result = runPropertySynchronously(property, config: config)
    
    switch result {
    case .success:
        break
    case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
        // Record issue with detailed failure report
        Issue.record(...)
    case .gaveUp(let discarded, let iterations):
        Issue.record("Property test gave up")
    }
}
```

### Constraints
- Must be applied to a function declaration.
- The function must have at least one parameter.
- All parameter types must have an inferable generator or an explicit `@Gen` attribute.

---

## @Gen

The `@Gen` macro is used as a parameter attribute within a `@Property` test to specify a custom generator for that parameter, overriding the default inferred generator.

### Usage Syntax

```swift
@Property
func testSomething(@Gen(generatorExpression) param: Type) { ... }
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| (unnamed) | `Expr` | (Required) | A generator expression (e.g., `.int`, `.string(length: 1...10)`, `MyType.customGen`). |

### Code Example

**Before Expansion:**

```swift
@Property
func testBoundedInteger(@Gen(Gen.int.inRange(1...100)) value: Int) {
    #expect(value >= 1 && value <= 100)
}
```

**Expansion Logic:**
The macro uses the provided `Gen.int.inRange(1...100)` expression instead of the default `Gen<Int>.int` when building the property's generator.

---

## @Arbitrary

The `@Arbitrary` macro automatically generates `arbitrary` and `shrink` implementations for custom types (structs and enums), enabling them to be used in property tests.

### Usage Syntax

```swift
@Arbitrary(
    shrink: ShrinkStrategy = .automatic,
    constraints: [String: String] = [:]
)
struct MyType { ... }
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `shrink` | `ShrinkStrategy` | `.automatic` | The shrinking strategy to use. Options: `.automatic`, `.none`, or `.towards(value)`. |
| `constraints` | `[String: String]` | `[:]` | Custom generator expressions for specific fields (e.g., `["age": "Gen.int.inRange(0...120)"]`). |

### Code Example

**Before Expansion:**

```swift
@Arbitrary(constraints: ["name": "Gen.string.suchThat { !$0.isEmpty }"])
struct User {
    let name: String
    let age: Int
}
```

**After Expansion (Simplified):**

```swift
extension User: Generatable {
    static var arbitrary: Gen<User> {
        Gen.zip(
            Gen.string.suchThat { !$0.isEmpty },
            Gen<Int>.int
        ).map { name, age in
            User(name: name, age: age)
        }
    }
    
    static var shrink: (User) -> [User] {
        // Automatic shrinking logic for struct fields
    }
}
```

### Constraints
- Must be applied to a `struct` or `enum` declaration.
- For structs, all fields must have an inferable generator or be specified in `constraints`.

---

## @Label

The `@Label` macro attaches a human-readable label to a parameter, which is used in failure reports to provide better context for counterexamples.

### Usage Syntax

```swift
@Property
func testLogin(@Label("Username") u: String, @Label("Password") p: String) { ... }
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| (unnamed) | `String` | (Required) | The label string to display in failure reports. |

### Code Example

**Before Expansion:**

```swift
@Property
func testAgeValidation(@Label("User Age") age: Int) {
    #expect(age >= 0)
}
```

**Expansion Logic:**
When a failure occurs, the report will display `User Age: -1` instead of just the value or parameter name.

---

## @BusinessRule

The `@BusinessRule` macro generates property tests for business logic functions, requiring a descriptive string and providing "smart" iteration defaults.

### Usage Syntax

```swift
@BusinessRule(
    "Description of the rule",
    iterations: Int or .smart = .smart,
    timeout: TimeInterval = 30.0
)
func ruleFunction(param: Type) -> Bool { ... }
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| (unnamed) | `String` | (Required) | A description of the business rule being tested. |
| `iterations` | `Int` / `.smart` | `.smart` | Number of iterations. `.smart` uses framework-optimized iteration counts based on complexity. |
| `timeout` | `TimeInterval`| `30.0` | Timeout in seconds for the entire test execution. |

### Code Example

**Before Expansion:**

```swift
@BusinessRule("Users must be at least 18 years old to access premium content")
func checkPremiumAccess(age: Int) -> Bool {
    return age >= 18
}
```

**After Expansion (Simplified):**

```swift
@Test("Users must be at least 18 years old to access premium content")
func checkPremiumAccess_PropertyTest() async throws {
    let property = Property<Int>(
        generator: Gen<Int>.int,
        predicate: { value in
            checkPremiumAccess(age: value)
        }
    )
    let config = PropertyConfig(iterations: PropertyConfig.smartIterations, ...)
    let runner = PropertyRunner()
    let result = await runner.runProperty(property, config: config)
    
    // Switch result and throw BusinessRuleViolation on failure
}
```

### Constraints
- Must be applied to a function that returns `Bool`.
- The function must have at least one parameter.

---

## @LawChecked

The `@LawChecked` macro automatically generates property-based tests for standard mathematical laws (e.g., Functor, Monad, Semigroup) based on type conformances.

> **Availability:** InvariantSwift 2.0+
>
> **Import:** `import InvariantSwift`

### Usage Syntax

```swift
@LawChecked(
    laws: [MathematicalLaw] = [],
    customLaws: [String: String] = [:],
    iterations: Int = 100,
    size: Int = 50,
    enableShrinking: Bool = true,
    timeout: Double = 30.0
)
struct MyType: Protocol { ... }
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `laws` | `[MathematicalLaw]` | `[]` | List of laws to check. Available values: `.functor`, `.applicative`, `.monad`, `.comonad`, `.semigroup`, `.monoid`, `.group`, `.ring`, `.field`, `.partialOrder`, `.totalOrder`, `.lattice`, `.metric`, `.norm`, `.foldable`, `.traversable`, `.bifunctor`, `.profunctor`. |
| `customLaws` | `[String: String]` | `[:]` | Dictionary mapping law names to property expressions. |
| `iterations` | `Int` | `100` | Number of test iterations per law. |
| `size` | `Int` | `50` | The size parameter used for value generation. |
| `enableShrinking` | `Bool` | `true` | Whether to enable shrinking for counterexamples. |
| `timeout` | `Double` | `30.0` | Timeout for each law test in seconds. |

### Code Example

**Before Expansion:**

```swift
@LawChecked(laws: [.functor])
struct MyBox<T>: Functor, Equatable {
    let value: T
    func map<U>(_ f: (T) -> U) -> MyBox<U> { MyBox<U>(value: f(value)) }
}
```

**After Expansion (Simplified):**

```swift
extension MyBox {
    @Test("MyBox Functor Identity Law: map(id) == id")
    func test_MyBox_FunctorIdentityLaw() async {
        // Generates property test for functor identity
    }
    
    @Test("MyBox Functor Composition Law: map(g ∘ f) == map(g) ∘ map(f)")
    func test_MyBox_FunctorCompositionLaw() async {
        // Generates property test for functor composition
    }
}
```

### Constraints
- The type must conform to the protocols corresponding to the laws being checked.
- The type should implement a static `gen` or `arbitrary` generator.

---

## @DeriveGen

The `@DeriveGen` macro automatically derives a `Gen<Self>` instance for a type, supporting structs, enums, and classes. It simplifies the creation of generators for complex domain models.

> **Availability:** InvariantSwift 2.0+
>
> **Import:** `import InvariantSwift`
>
> **Difference from @Arbitrary:**
> - `@Arbitrary` generates an `arbitrary` property and is the primary macro for most use cases
> - `@DeriveGen` generates a `gen` property and offers advanced configuration options (maxDepth, sizeScaling)
> - Use `@Arbitrary` for simple cases, `@DeriveGen` when you need fine-grained control over generation

### Usage Syntax

```swift
@DeriveGen(
    customFields: [String: String] = [:],
    maxDepth: Int = 5,
    sizeScaling: Double = 1.0,
    enableShrinking: Bool = true
)
struct MyModel { ... }
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `customFields` | `[String: String]` | `[:]` | Custom generators for specific fields (e.g., `["email": "Gen.email"]`). |
| `maxDepth` | `Int` | `5` | Maximum recursion depth for nested or recursive types. |
| `sizeScaling` | `Double` | `1.0` | Factor to scale the generation size parameter. |
| `enableShrinking` | `Bool` | `true` | Whether to generate shrinking logic for the type. |

### Code Example

**Before Expansion:**

```swift
@DeriveGen(customFields: ["email": "Gen.email"])
struct Profile {
    let username: String
    let email: String
    let age: Int
}
```

**After Expansion (Simplified):**

```swift
extension Profile {
    public static var gen: Gen<Profile> {
        Gen.zip(
            Gen<String>.string,
            Gen.email,
            Gen<Int>.int
        ).map { username, email, age in
            Profile(username: username, email: email, age: age)
        }
    }
}
```

### Constraints
- All fields must have an inferable generator or be specified in `customFields`.
- For classes, a memberwise initializer or a default initializer must be accessible.

---

## @Equivalence

The `@Equivalence` macro generates property-based tests to verify that two function implementations produce equivalent outputs across randomly generated inputs. This is essential for safe refactoring, algorithm optimization, and migration validation.

> **Availability:** InvariantSwift 2.0+
>
> **Import:** `import InvariantSwift`

### Usage Syntax

```swift
@Equivalence(
    iterations: Int = 500,
    tolerance: Double? = nil
)
func testFunctionName(
    reference: @escaping (Input) -> Output,
    candidate: @escaping (Input) -> Output
) {
}
```

### Parameters

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `iterations` | `Int` | `500` | Number of randomly generated inputs to test. |
| `tolerance` | `Double?` | `nil` | Optional tolerance for floating-point comparisons. When `nil`, uses exact equality (`!=`). When specified, uses `isApproximatelyEqual(to:tolerance:)` with `FloatingPointTolerance.absolute(tolerance)`. |

### Use Cases

**Safe Refactoring:**
Verify that an optimized implementation produces the same results as the original.

**Algorithm Comparison:**
Compare multiple implementations of the same algorithm (e.g., sorting algorithms).

**Migration Validation:**
Ensure new code produces identical outputs to legacy code during incremental migration.

### Code Examples

#### Basic Usage (Exact Equality)

**Before Expansion:**

```swift
@Equivalence(iterations: 1000)
func testSortEquivalence(
    reference: @escaping ([Int]) -> [Int],
    candidate: @escaping ([Int]) -> [Int]
) {
}
```

**After Expansion (Simplified):**

```swift
private enum testSortEquivalence_EquivalenceTest {
    @Test("testSortEquivalence")
    static func run() throws {
        for _ in 0..<1000 {
            var rng = SystemRandomNumberGenerator()
            let input = Gen<[Int]>.array(Gen<Int>.int).generate(&rng, Size.default)

            let referenceResult = reference(input)
            let candidateResult = candidate(input)

            if referenceResult != candidateResult {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
            }
        }
    }
}
```

#### Floating-Point Comparison with Tolerance

**Before Expansion:**

```swift
@Equivalence(iterations: 500, tolerance: 0.0001)
func testNumericalMethodEquivalence(
    reference: @escaping (Double) -> Double,
    candidate: @escaping (Double) -> Double
) {
}
```

**After Expansion (Simplified):**

```swift
private enum testNumericalMethodEquivalence_EquivalenceTest {
    @Test("testNumericalMethodEquivalence")
    static func run() throws {
        for _ in 0..<500 {
            var rng = SystemRandomNumberGenerator()
            let input = Gen<Double>.double.generate(&rng, Size.default)

            let referenceResult = reference(input)
            let candidateResult = candidate(input)

            if !referenceResult.isApproximatelyEqual(to: candidateResult, tolerance: .absolute(0.0001)) {
                Issue.record(Comment(rawValue: "Equivalence test failed: reference and candidate produced different outputs"))
            }
        }
    }
}
```

#### Multiple Input Parameters

The macro automatically infers generators for multiple input parameters:

```swift
@Equivalence(iterations: 300)
func testStringTransformEquivalence(
    reference: @escaping (String, Int) -> String,
    candidate: @escaping (String, Int) -> String
) {
}
```

Generates: `Gen<String>.string.zip(Gen<Int>.int)` for tuple input generation.

### Supported Types

**Exact Comparison (tolerance: nil):**
- Any `Equatable` type
- Arrays: `[T]` where `T: Equatable`
- Optionals: `T?` where `T: Equatable`
- Tuples, custom types

**Tolerance Comparison (tolerance: Double):**
- `Double`
- `Float`
- `Float16`
- `Float80`
- `CGFloat`

### Error Handling

The macro validates usage at compile time and emits clear diagnostics:

**Error: Applied to non-function**
```swift
@Equivalence(iterations: 100)
var testVariable: Int = 42  // Error: @Equivalence can only be applied to functions
```

**Error: Wrong parameter count**
```swift
@Equivalence(iterations: 100)
func testWrong(x: Int) {}  // Error: @Equivalence requires exactly two function parameters (reference, candidate)
```

**Error: Tolerance on non-floating-point type**
```swift
@Equivalence(tolerance: 0.1)
func testIntEquivalence(
    reference: @escaping (Int) -> Int,
    candidate: @escaping (Int) -> Int
) {}  // Error: tolerance parameter requires Output type to conform to BinaryFloatingPoint (Double, Float, Float16, Float80, CGFloat)
```

**Error: Incompatible function types**
```swift
@Equivalence(iterations: 100)
func testIncompatible(
    reference: @escaping (Int) -> Int,
    candidate: String  // Error: Reference and candidate functions must have matching signatures
) {}
```

### Generated Code Structure

The macro generates:
1. **Private wrapper enum** named `{functionName}_EquivalenceTest`
2. **Static `@Test` function** named `run()`
3. **For loop** iterating `iterations` times
4. **Input generation** using inferred `Gen<T>` generators
5. **Function calls** to both reference and candidate with same input
6. **Comparison logic** (exact or tolerance-based)
7. **Issue recording** on divergence

### Edge Cases

**Async functions:**
```swift
@Equivalence(iterations: 100)
func testAsyncEquivalence(
    reference: @escaping (Int) async -> Int,
    candidate: @escaping (Int) async -> Int
) {}
```
Generates: `static func run() async throws { ... }`

**Throwing functions:**
```swift
@Equivalence(iterations: 100)
func testThrowingEquivalence(
    reference: @escaping (Int) throws -> Int,
    candidate: @escaping (Int) throws -> Int
) {}
```
Generates: `static func run() throws { ... }` with proper `try` handling

### See Also

- [@Property](#property) - General property-based testing
- [@DifferentialTest](#differentialtest) - Differential testing across implementations
- [PropertyConfig](../Sources/InvariantSwift/Property/PropertyConfig.swift) - Configuration options

### Constraints

- Must be applied to a function declaration.
- The function must have exactly two parameters.
- Both parameters must be function types with matching signatures.
- When `tolerance` is specified, the output type must conform to `BinaryFloatingPoint`.
- Input types must have inferable generators (Int, String, Bool, arrays, optionals, etc.).

---

## Property Assertion Macros

Property assertion macros automatically generate property tests that verify common function properties: idempotency, determinism, and purity.

> **Availability:** InvariantSwift 2.0+
>
> Import: `import InvariantSwift`

### @Idempotent

Verifies that a function is idempotent: applying it multiple times produces the same result as applying it once.

**Mathematical Definition:** `f(f(x)) == f(x)` for all x in the domain.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `iterations` | Int | 100 | Number of random inputs to test |
| `applicationCount` | Int | 2 | How many times to apply f before checking stability |

**Requirements:**
- Must be applied to a function (not a property or type)
- Function must have at least one parameter
- Return type must conform to Equatable

**Use Cases:**
- Data normalization (trimming, case folding, path canonicalization)
- Caching and memoization validation
- Retry logic safety
- State machine reset operations

**Example:**
```swift
@Idempotent
func normalize(_ text: String) -> String {
  text.trimmingCharacters(in: .whitespaces).lowercased()
}

// Generates test verifying:
// normalize(normalize(text)) == normalize(text)
```

**With Custom Parameters:**
```swift
@Idempotent(iterations: 500, applicationCount: 3)
func stabilize(_ data: Data) -> Data {
  // Function that may need multiple applications to stabilize
}
```

### @Deterministic

Verifies that a function is deterministic: calling it multiple times with the same input always produces the same output.

**Mathematical Definition:** `f(x) == f(x)` for all x, across multiple calls.

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `iterations` | Int | 100 | Number of random inputs to test |
| `callCount` | Int | 2 | How many times to call f with same input |

**Requirements:**
- Must be applied to a function (not a property or type)
- Function must have at least one parameter
- Return type must conform to Equatable

**Use Cases:**
- Hash function verification
- Serialization/encoding consistency
- Reproducible build verification
- Random number generator seeding validation

**Example:**
```swift
@Deterministic
func hash(_ value: String) -> Int {
  value.hashValue  // Warning: Swift's hashValue is not stable across runs!
}

// Generates test verifying:
// hash(value) == hash(value) for multiple calls
```

**With Custom Parameters:**
```swift
@Deterministic(iterations: 1000, callCount: 5)
func encode(_ model: User) -> Data {
  try! JSONEncoder().encode(model)
}
```

### @Pure

Documents that a function is intended to be pure (no side effects, referentially transparent).

**Important Limitation:** Swift lacks effect tracking like Haskell's type system. `@Pure` can only verify determinism (that the function returns the same result for the same input). It **cannot detect**:
- State mutations to captured variables
- I/O operations (file, network, console)
- Global state modifications
- Observable side effects

**What @Pure Actually Tests:** Determinism (`f(x) == f(x)`)

**What @Pure Cannot Test:** Absence of side effects

**Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `iterations` | Int | 100 | Number of random inputs to test |
| `callCount` | Int | 2 | How many times to call f with same input |

**Requirements:**
- Must be applied to a function (not a property or type)
- Function must have at least one parameter
- Return type must conform to Equatable

**Use Cases:**
- Documenting functions safe for memoization
- Identifying functions safe for parallel execution
- Self-documenting code for pure function contracts
- Verifying determinism as a subset of purity

**Example:**
```swift
@Pure
func add(_ a: Int, _ b: Int) -> Int {
  a + b  // Truly pure: no side effects
}

// Generates test verifying determinism (a subset of purity):
// add(a, b) == add(a, b)
```

**Recommendation:** Use @Pure for documentation purposes and determinism verification. For true purity guarantees, combine with code review for side effect detection.
