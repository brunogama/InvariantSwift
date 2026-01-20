# ISP-0002: Composite Generators with `#draw`

- **Status:** Implemented
- **Priority:** P0 (Critical)
- **Author:** InvariantSwift Team
- **Created:** 2025-01-17
- **Swift Version:** 6.1+

## Summary

Introduce the `@Composite` macro and `#draw` expression macro to enable declarative construction of dependent generators where later values depend on earlier ones, while preserving shrinking capabilities.

## Motivation

### The Problem

Property-based testing often requires generating values that depend on each other. Current approaches in Swift are verbose and error-prone:

**SwiftCheck Style (Monadic):**
```swift
// Generate (a, b) where a <= b
let orderedPairGen: Gen<(Int, Int)> = Int.arbitrary.flatMap { a in
    Int.arbitrary.suchThat { $0 >= a }.map { b in
        (a, b)
    }
}
```

**Problems:**
1. **Verbose**: Simple constraints require nested closures
2. **Hard to read**: The intent is buried in monadic plumbing
3. **Easy to break shrinking**: Manual `flatMap` can lose shrink information
4. **Doesn't scale**: Complex dependencies become unreadable

**Real-World Example — Valid User:**
```swift
// A user where canDrink is only true if age >= 21
let validUserGen: Gen<User> = Gen<Int>.choose(from: 0...120).flatMap { age in
    let canDrink = age >= 21
    if canDrink {
        return Gen<String?>.oneOf([
            Gen.pure(nil),
            String.arbitrary.map { Optional($0) }
        ]).map { bar in
            User(age: age, canDrink: canDrink, favoriteBar: bar)
        }
    } else {
        return Gen.pure(User(age: age, canDrink: false, favoriteBar: nil))
    }
}
```

This 15-line monstrosity expresses a simple business rule!

### The Solution

Declarative syntax using `@Composite` and `#draw`:

```swift
@Composite
func validUser() -> Gen<User> {
    let age = #draw(from: .int(0...120))
    let canDrink = age >= 21
    let favoriteBar = canDrink ? #draw(from: .optional(.string)) : nil
    return User(age: age, canDrink: canDrink, favoriteBar: favoriteBar)
}
```

**Benefits:**
- Reads like normal Swift code
- Dependencies are obvious (normal variable references)
- Shrinking is preserved automatically
- 4 lines vs 15 lines

## Detailed Design

### The `@Composite` Macro

```swift
@attached(body)
public macro Composite() = #externalMacro(
    module: "InvariantSwiftMacros",
    type: "CompositeMacro"
)
```

Applied to a function that returns `Gen<T>`, transforms the body to use monadic binding while appearing imperative.

### The `#draw` Expression Macro

```swift
@freestanding(expression)
public macro draw<T>(
    from generator: Gen<T>
) -> T = #externalMacro(
    module: "InvariantSwiftMacros",
    type: "DrawMacro"
)

@freestanding(expression)
public macro draw<T: Generatable>(
    _ type: T.Type
) -> T = #externalMacro(
    module: "InvariantSwiftMacros",
    type: "DrawMacro"
)

@freestanding(expression)
public macro draw<T: Generatable>(
    _ type: T.Type,
    _ constraint: GeneratorConstraint<T>
) -> T = #externalMacro(
    module: "InvariantSwiftMacros",
    type: "DrawMacro"
)
```

### Expansion Example

**Input:**
```swift
@Composite
func orderedPair() -> Gen<(Int, Int)> {
    let a = #draw(Int.self)
    let b = #draw(Int.self, .greaterThan(a))
    return (a, b)
}
```

**Expands to:**
```swift
func orderedPair() -> Gen<(Int, Int)> {
    Gen<Int>.arbitrary.flatMap { a in
        Gen<Int>.arbitrary
            .suchThat { $0 > a }
            .withShrinker { Shrink.towards(a + 1, $0) }
            .map { b in
                (a, b)
            }
    }
}
```

### Constraint DSL

```swift
public enum GeneratorConstraint<T> {
    // Numeric constraints
    case greaterThan(_ value: T) where T: Comparable
    case lessThan(_ value: T) where T: Comparable
    case between(_ range: ClosedRange<T>) where T: Comparable
    case notEqual(_ value: T) where T: Equatable
    
    // Collection constraints
    case nonEmpty where T: Collection
    case count(_ range: Range<Int>) where T: Collection
    case containing(_ element: T.Element) where T: Collection, T.Element: Equatable
    case unique where T: Collection, T.Element: Hashable
    
    // String constraints
    case matching(_ regex: Regex<Substring>) where T == String
    case alphabetic where T == String
    case alphanumeric where T == String
    
    // Custom
    case satisfying(_ predicate: @Sendable (T) -> Bool)
}
```

### Complex Examples

**Sorted Array:**
```swift
@Composite
func sortedArray() -> Gen<[Int]> {
    let count = #draw(Int.self, .between(0...100))
    var result: [Int] = []
    var lastValue = Int.min
    
    for _ in 0..<count {
        let next = #draw(Int.self, .greaterThan(lastValue))
        result.append(next)
        lastValue = next
    }
    
    return result
}
```

**Valid Binary Tree:**
```swift
@Composite
func validBST(range: ClosedRange<Int> = Int.min...Int.max) -> Gen<BST?> {
    let shouldBeNil = #draw(Bool.self)
    guard !shouldBeNil else { return nil }
    
    let value = #draw(Int.self, .between(range))
    let left = #draw(from: validBST(range: range.lowerBound...(value - 1)))
    let right = #draw(from: validBST(range: (value + 1)...range.upperBound))
    
    return BST(value: value, left: left, right: right)
}
```

**API Request with Auth:**
```swift
@Composite
func authenticatedRequest() -> Gen<APIRequest> {
    let user = #draw(User.self)
    let tokenType: TokenType = #draw(from: .element(of: user.allowedTokenTypes))
    let token = #draw(from: tokenGenerator(for: tokenType))
    let endpoint = #draw(from: .element(of: user.accessibleEndpoints))
    
    return APIRequest(
        user: user,
        token: token,
        endpoint: endpoint
    )
}
```

**Dependent Network Mock:**
```swift
@Composite
func consistentNetworkMock() -> Gen<NetworkMock> {
    let latency = #draw(from: .duration(.milliseconds(1)...(.seconds(5))))
    let shouldFail = #draw(Bool.self)
    
    let response: Response
    if shouldFail {
        let errorCode = #draw(from: .element(of: [400, 401, 403, 404, 500, 502, 503]))
        response = .error(code: errorCode)
    } else {
        let body = #draw(Data.self, .count(0..<10_000))
        response = .success(body: body, latency: latency)
    }
    
    return NetworkMock(response: response)
}
```

### Shrinking Preservation

The key innovation is **integrated shrinking** — each `#draw` captures its shrink tree:

```swift
// Conceptual model
struct DrawnValue<T> {
    let value: T
    let shrinkTree: ShrinkTree<T>
    let dependencies: [AnyDrawnValue]
}
```

When shrinking a composite generator:
1. Try shrinking the last drawn value first
2. If that doesn't reduce the failure, try earlier values
3. Respect dependencies (don't shrink `a` past where `b > a` fails)

### Control Flow Support

`#draw` works inside control flow:

```swift
@Composite
func maybeWrapped<T: Generatable>(_ inner: Gen<T>) -> Gen<Wrapper<T>?> {
    if #draw(Bool.self) {
        let value = #draw(from: inner)
        return Wrapper(value)
    } else {
        return nil
    }
}
```

Expands to proper monadic branching:
```swift
func maybeWrapped<T: Generatable>(_ inner: Gen<T>) -> Gen<Wrapper<T>?> {
    Bool.arbitrary.flatMap { condition in
        if condition {
            inner.map { value in Wrapper(value) }
        } else {
            Gen.pure(nil)
        }
    }
}
```

## When to Use

### ✅ Ideal Use Cases

1. **Ordered/Sorted Data**
   ```swift
   @Composite
   func sortedPair() -> Gen<(Int, Int)> {
       let a = #draw(Int.self)
       let b = #draw(Int.self, .greaterThan(a))
       return (a, b)
   }
   ```

2. **Hierarchical Structures**
   ```swift
   @Composite
   func orgChart() -> Gen<Employee> {
       let ceo = #draw(Employee.self)
       let reportCount = #draw(Int.self, .between(0...5))
       let reports = (0..<reportCount).map { _ in
           #draw(from: employee(reportsTo: ceo.id))
       }
       return ceo.with(directReports: reports)
   }
   ```

3. **Constrained Business Objects**
   ```swift
   @Composite
   func validOrder() -> Gen<Order> {
       let customer = #draw(Customer.self)
       let items = #draw([Product].self, .nonEmpty)
       let discount = customer.isPremium 
           ? #draw(from: .percentage(0...30))
           : #draw(from: .percentage(0...10))
       return Order(customer: customer, items: items, discount: discount)
   }
   ```

4. **Protocol-Compliant Data**
   ```swift
   @Composite
   func validJSON() -> Gen<JSON> {
       let depth = #draw(Int.self, .between(0...5))
       return #draw(from: jsonValue(maxDepth: depth))
   }
   ```

5. **State-Dependent Sequences**
   ```swift
   @Composite
   func validCommandSequence() -> Gen<[Command]> {
       var state = initialState
       var commands: [Command] = []
       let count = #draw(Int.self, .between(1...20))
       
       for _ in 0..<count {
           let cmd = #draw(from: validCommand(for: state))
           commands.append(cmd)
           state = state.applying(cmd)
       }
       
       return commands
   }
   ```

### ❌ When NOT to Use

1. **Independent values** — Just use `@PropertyTest` with multiple parameters
2. **Simple type composition** — Use `@Arbitrary` macro instead
3. **Static constraints** — Use generator methods directly (`.int(0...100)`)

## Importance

### Why This Matters

1. **Massive Ergonomic Improvement**
   - 3-5x less code for dependent generators
   - Reads like normal Swift (no monad tutorial required)
   - Lower barrier to entry for property-based testing

2. **Correct by Construction**
   - Shrinking is automatic and correct
   - No manual `flatMap` chains to mess up
   - Dependencies are tracked by the macro

3. **Competitive Advantage**
   - Hypothesis (Python): Has `@composite` decorator — industry standard
   - fast-check (JS): Has `fc.gen()` — very popular
   - SwiftCheck: Nothing — forces monadic style
   - **InvariantSwift would be first Swift framework with this**

4. **Enables Complex Testing**
   - Makes previously impractical generators practical
   - Encourages testing of complex domain objects
   - Reduces "I'll just hard-code some examples" temptation

### Comparison

| Approach | Lines of Code | Readability | Shrinking | Error-Prone |
|----------|---------------|-------------|-----------|-------------|
| Manual flatMap | 15-30 | Poor | Manual | Very |
| @Composite | 4-8 | Excellent | Automatic | No |

## Implementation Notes

### Phase 1: Basic `#draw`
- Support for simple type inference
- Basic constraint operators
- Linear control flow only

### Phase 2: Advanced Features
- Loop support with mutable state
- Recursive composites
- Cross-draw shrinking optimization

### Phase 3: Integration
- Integration with `@PropertyTest`
- Integration with `@Arbitrary`
- IDE support (autocomplete, type hints)

### Macro Implementation Strategy

The macro performs these transformations:

1. **Identify `#draw` calls** in the function body
2. **Extract dependencies** between draws
3. **Convert to continuation-passing style** internally
4. **Generate `flatMap` chain** with proper shrinking
5. **Preserve source locations** for error messages

## Alternatives Considered

### 1. Result Builder Syntax
```swift
@GeneratorBuilder
func orderedPair() -> Gen<(Int, Int)> {
    Draw { Int.arbitrary } into: { a in
        Draw { Int.arbitrary.filter { $0 > a } } into: { b in
            Return((a, b))
        }
    }
}
```
- **Rejected**: Too verbose, doesn't read naturally

### 2. Property Wrapper Approach
```swift
func orderedPair() -> Gen<(Int, Int)> {
    @Draw var a: Int
    @Draw(constraint: .greaterThan(a)) var b: Int
    return (a, b)
}
```
- **Rejected**: Property wrappers can't capture scope properly

### 3. Async/Await Mirroring
```swift
func orderedPair() async -> (Int, Int) {
    let a = await draw(Int.self)
    let b = await draw(Int.self, .greaterThan(a))
    return (a, b)
}
```
- **Rejected**: Overloads async semantics confusingly

## References

- [Hypothesis @composite Decorator](https://hypothesis.readthedocs.io/en/latest/data.html#composite-strategies)
- [fast-check fc.gen()](https://fast-check.dev/docs/advanced/custom-arbitraries/#fcgen)
- [Hedgehog Gen Monad](https://hackage.haskell.org/package/hedgehog-1.4/docs/Hedgehog-Gen.html)
- [QuickCheck Monadic API](https://hackage.haskell.org/package/QuickCheck-2.14.3/docs/Test-QuickCheck-Monadic.html)
