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
| `laws` | `[MathematicalLaw]` | `[]` | List of laws to check (e.g., `.functor`, `.applicative`, `.monad`, `.semigroup`, `.monoid`). |
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
extension Profile: Generatable {
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
