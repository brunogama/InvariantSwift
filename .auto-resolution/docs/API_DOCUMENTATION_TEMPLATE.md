# API Documentation Template - InvariantSwift 1.0

**Document Status**: Active | **Last Updated**: 2026-01-16 | **Version**: 1.0-draft

This document provides the comprehensive template and compliance requirements for all public API documentation in InvariantSwift. All 82 public symbols must follow these standards before 1.0 release.

## 1. Documentation Standards

### 1.1 Core Principles

- **Clarity First**: Documentation is for users, not implementers
- **Completeness**: Every public symbol requires documentation
- **Consistency**: Same patterns across all APIs
- **Discoverability**: Proper markup for IDE integration
- **Executability**: Code examples must compile and run

### 1.2 Required Elements (Mandatory)

For every public type, function, method, property:

| Element | Required | Location | Purpose |
|---------|----------|----------|---------|
| **Summary** | ✅ Yes | First line | One-liner describing purpose |
| **Discussion** | ✅ Yes | Main text | Detailed explanation, use cases |
| **Parameters** | ✅ Yes (if applicable) | `- Parameters:` section | Explain each input |
| **Returns** | ✅ Yes (if applicable) | `- Returns:` section | Explain return value |
| **Throws** | ✅ Yes (if applicable) | `- Throws:` section | Document error conditions |
| **Example** | ✅ Yes | `- Snippet:` or code block | Compilable usage example |
| **Notes** | ❌ Optional | `- Note:` or `- Important:` | Caveats, constraints, context |
| **See Also** | ❌ Optional | End of comment | Related APIs |

### 1.3 Compliance Validation Rules

Before marking a symbol as documented:

- [ ] Symbol appears in public API audit (docs/API_AUDIT.md)
- [ ] All required elements present (see 1.2 table)
- [ ] Example code compiles without warnings or errors
- [ ] No internal implementation details in documentation
- [ ] No hardcoded examples (use variables/placeholders)
- [ ] Mathematical concepts include external references
- [ ] Accessibility considerations documented (if applicable)
- [ ] Concurrency constraints documented (async, actor isolation)

---

## 2. DocC Comment Format

### 2.1 Basic Structure

```swift
/// One-line summary describing the primary purpose.
///
/// Detailed explanation covering:
/// - What this type/function does
/// - When to use it
/// - Key characteristics or constraints
/// - Connection to mathematical laws (if applicable)
///
/// For example, `Gen<T>` represents a random generator producing values
/// of type `T` with built-in shrinking support. It follows functor laws.
///
/// - Parameters:
///   - seed: The `Seed` value for reproducible generation
///   - size: The generation size hint (affects shrinking depth)
///
/// - Returns: A tuple of (generated value, shrink tree for minimization)
///
/// - Note: Important: Thread-safe; may be called from multiple actors
///
/// - Snippet:
///   ```swift
///   let gen = Gen.integer(in: 0..<100)
///   let (value, shrinks) = gen.generate(seed: seed, size: 50)
///   ```
///
/// - See Also: ``Property``, ``Seed``, ``Shrink``
public struct Gen<T> { ... }
```

### 2.2 Formatting Rules

#### Multi-paragraph Discussion

```swift
/// One-liner summary.
///
/// First paragraph of detailed explanation. This can be multiple sentences
/// and should cover the main use case and benefits.
///
/// Second paragraph if needed. Additional context about constraints,
/// performance characteristics, or integration points.
///
/// Third paragraph for advanced usage or mathematical foundations.
```

#### Inline Code vs Code Blocks

```swift
/// Use `backticks` for inline type/variable names: `Gen<Int>`, `Property`
///
/// Use triple-backtick blocks for multi-line code examples:
///
/// ```swift
/// let gen = Gen.string(characterSet: .alphanumerics)
/// let property = Property(generator: gen) { str in
///     #expect(str.count > 0)
/// }
/// ```
```

#### Parameters Documentation

```swift
/// - Parameters:
///   - generator: The `Generator` providing test inputs.
///     Must produce values suitable for the property check.
///   - numberOfTests: The number of test cases to generate. Default: 100.
///     Values should be in range 10...10000 for meaningful coverage.
///   - seed: Optional `Seed` for reproducibility. If nil, uses system randomness.
```

#### Throws Documentation

```swift
/// - Throws: `PropertyError` if property fails before reaching count,
///   or `GeneratorError` if generator cannot produce valid values.
```

#### Complex Returns

```swift
/// - Returns: A tuple containing:
///   - `result`: The `PropertyResult` indicating pass/fail/error
///   - `report`: A `PropertyReport` with statistics and coverage data
///   - `counterexample`: The minimal failing input (if result == .failed)
```

---

## 3. Category-Specific Templates

### 3.1 Protocols

```swift
/// Protocol for values that support shrinking to simpler counterexamples.
///
/// Types conforming to `Shrinkable` must provide a sequence of progressively
/// simpler representations of themselves. This enables finding the minimal
/// input that triggers a property failure.
///
/// The shrinking sequence should follow these laws:
/// - Every shrink must be simpler (by some metric) than the original
/// - The sequence should be finite but can be very long
/// - Shrinks of shrinks should not exceed depth D (prevents exponential growth)
///
/// Mathematical foundation: This implements coalgebraic shrinking trees,
/// reducing the state space exponentially during fault localization.
/// See: [TBD academic reference]
///
/// - Conformance Requirements:
///   - Implement ``Shrinkable/shrinks-swift.property`` returning shrink values
///   - Ensure shrink tree terminates (no infinite cycles)
///   - Shrinks should cover multiple "directions" of simplification
///
/// - Example:
///   ```swift
///   struct SimpleShrinkable: Shrinkable {
///       let value: Int
///
///       var shrinks: [SimpleShrinkable] {
///           guard value > 0 else { return [] }
///           return [
///               SimpleShrinkable(value: 0),
///               SimpleShrinkable(value: value / 2),
///               SimpleShrinkable(value: value - 1)
///           ]
///       }
///   }
///   ```
///
/// - See Also: ``Shrink``, ``Generator``, ``Property``
public protocol Shrinkable { ... }
```

### 3.2 Structs / Classes

```swift
/// A deterministic random number generator seeded for reproducible generation.
///
/// `SeededRandomNumberGenerator` allows property-based tests to reproduce
/// failing cases by replaying the same seed value. Each seed-size combination
/// produces a deterministic sequence of random values.
///
/// Key characteristics:
/// - Deterministic: Same seed always produces same sequence
/// - Cryptographically insecure (use for testing only, not security)
/// - O(1) per value generation, O(log n) next-seed computation
/// - Thread-safe (value type, copied on assignment)
///
/// For detailed mathematical foundation, see the Lehmer PRNG documentation
/// at [https://en.wikipedia.org/wiki/Lehmer_random_number_generator].
///
/// - Parameters:
///   - initialValue: Starting seed value (typically derived from Date or entropy)
///
/// - Example:
///   ```swift
///   let seed = Seed(value: 12345)
///   var rng = SeededRandomNumberGenerator(seed: seed)
///
///   let random1 = Int.random(in: 0..<100, using: &rng)  // Always same for seed
///   let random2 = Int.random(in: 0..<100, using: &rng)  // Different, but reproducible
///   ```
///
/// - Note: Important: Do not use for security purposes. Use `SecureRandom` or
///   `CryptoKit` for cryptographic needs.
///
/// - See Also: ``Seed``, ``Property``, ``PropertyRunner``
public struct SeededRandomNumberGenerator: RandomNumberGenerator { ... }
```

### 3.3 Enums

```swift
/// The outcome of running a property-based test.
///
/// `PropertyResult` indicates whether the property held for all test cases,
/// failed on a specific input, or encountered an error during generation
/// or checking.
///
/// - Cases:
///   - `.passed`: Property held for all generated test cases
///   - `.failed(counterexample:)`: Property failed on this input; includes minimal shrink
///   - `.error(reason:)`: Test runner encountered an error (generator failure, etc.)
///   - `.undecided`: Insufficient coverage (predicate too restrictive)
///
/// - Example:
///   ```swift
///   let result = property.check(iterations: 100)
///
///   switch result {
///   case .passed:
///       print("✓ Property held for all test cases")
///   case .failed(let counterexample):
///       print("✗ Failed on input: \(counterexample)")
///   case .error(let reason):
///       print("⚠ Error: \(reason)")
///   case .undecided:
///       print("? Insufficient coverage - make predicate less restrictive")
///   }
///   ```
///
/// - See Also: ``Property``, ``PropertyRunner``, ``PropertyReport``
public enum PropertyResult { ... }
```

### 3.4 Functions / Methods

```swift
/// Generates `count` random values using the provided generator.
///
/// This is the primary entry point for running property-based tests. It
/// generates `count` independent test cases using the generator, checking
/// the property against each. Returns on first failure unless `stopOnError`
/// is false.
///
/// The generation sequence is deterministic when seeded, enabling:
/// - Reproducible test failures
/// - Regression testing via recorded seeds
/// - Parallel test distribution with different seed ranges
///
/// Performance: O(n) in count, where each generation is O(1) average case
/// and O(log n) worst case (for shrinking tree construction).
///
/// - Parameters:
///   - count: Number of test cases to generate. Default: 100.
///     Practical range: 10 (quick sanity check) to 100,000 (stress testing).
///   - stopOnError: Whether to stop after first failure. Default: true.
///     Set to false for exhaustive testing of all inputs.
///   - reporter: Optional closure called after each test (e.g., for progress).
///
/// - Returns: The first `PropertyResult` encountered (`.failed` if any failed).
///
/// - Throws: `PropertyError.generationFailed` if generator cannot create values
///   for more than 50% of attempts (indicates misconfigured generator).
///
/// - Precondition: count >= 1
///
/// - Example:
///   ```swift
///   let gen = Gen.array(of: Gen.integer(in: 0..<100))
///   let property = Property(generator: gen) { array in
///       #expect(array.isEmpty || array.min() <= array.max()!)
///   }
///
///   let result = try await property.check(
///       count: 1000,
///       reporter: { progress in
///           print("Test \(progress.current)/\(progress.total)")
///       }
///   )
///   ```
///
/// - Important: Property must not have side effects beyond assertions.
///   Each test case should be independent.
///
/// - See Also: ``Property``, ``Generator``, ``PropertyResult``
@discardableResult
public func check(
    count: Int = 100,
    stopOnError: Bool = true,
    reporter: ((PropertyProgress) -> Void)? = nil
) async -> PropertyResult { ... }
```

### 3.5 Operators

```swift
/// Composes two generators sequentially.
///
/// The operator `gen1 |> gen2` generates from `gen1`, then uses that result
/// to generate from `gen2`, supporting dependent generation patterns.
///
/// Example use case: Generate a collection size `n`, then generate exactly
/// `n` elements. Contrast with independent generation.
///
/// - Parameters:
///   - lhs: First generator providing initial value of type `A`
///   - rhs: Function mapping `A` to generator of type `B`
///
/// - Returns: Generator of type `B` with composed randomness and shrinking
///
/// - Example:
///   ```swift
///   // Generate size, then that many strings
///   let composed = Gen.integer(in: 0..<10)
///       |> { size in
///           Gen.array(of: Gen.string(), count: size)
///       }
///   ```
///
/// - Note: Binds tighter than function application but looser than member access
///
/// - See Also: ``Gen.flatMap(_:)``, ``Gen.map(_:)``
infix operator |>
```

---

## 4. Mathematical / Functional Programming APIs

### 4.1 Law Verification

```swift
/// Verifies that a generator satisfies the functor identity law.
///
/// The functor identity law requires that mapping the identity function
/// produces an equivalent generator (in distribution and shrinking).
///
/// Formally: `gen.map { $0 } == gen` (in distribution)
///
/// This is a meta-property: it checks that generators correctly implement
/// the functor protocol. See [Haskell functor laws](https://wiki.haskell.org/Functor)
/// for mathematical background.
///
/// Implementation note: Equivalence uses statistical testing
/// (Kolmogorov-Smirnov test) to avoid exact equality checks
/// which may be false negatives for probabilistic distributions.
///
/// - Parameters:
///   - generator: The `Generator` to verify
///   - samples: Number of samples for KS test. Default: 1000.
///     Increase for stricter statistical confidence.
///   - significance: P-value threshold for KS test. Default: 0.05.
///
/// - Returns: `VerificationResult` indicating law compliance
///
/// - Throws: `GeneratorError` if generator fails to produce values
///
/// - Example:
///   ```swift
///   let result = try verifyFunctorIdentity(
///       generator: Gen.integer(in: 0..<100),
///       samples: 5000
///   )
///
///   if result.holds {
///       print("✓ Functor identity law verified")
///   } else {
///       print("✗ Law violation: \(result.evidence)")
///   }
///   ```
///
/// - Note: This is a property-meta-property (checks a property of properties)
///   Useful for validating generator implementations but not typically needed
///   in user code.
///
/// - See Also: ``verifyFunctorComposition(_:_:_:)``,
///   ``verifyMonadLeftIdentity(_:_:)``
public func verifyFunctorIdentity<T>(
    generator: Gen<T>,
    samples: Int = 1000,
    significance: Double = 0.05
) -> VerificationResult { ... }
```

### 4.2 Optics (Lenses, Prisms)

```swift
/// A lens providing focused access to a field for immutable updates.
///
/// Lenses compose the getter and setter for a particular field into a single
/// abstraction, enabling:
/// - Functional field updates without mutation
/// - Composition of nested field accesses
/// - Automatic shrinking along focus path
///
/// Mathematically: A lens is a pair of functions (get, set) satisfying:
/// - Get-set law: `set(get(s), s) == s`
/// - Set-get law: `get(set(v, s)) == v`
/// - Set-set law: `set(v2, set(v1, s)) == set(v2, s)`
///
/// See [Edward Kmett's lens tutorial](https://ekmett.github.io) for background.
///
/// - Generic Parameters:
///   - `Whole`: The parent type being focused
///   - `Part`: The focused field type
///
/// - Properties:
///   - `get(_:)`: Extract the focused value from the whole
///   - `set(_:_:)`: Update the focused value in the whole
///
/// - Example:
///   ```swift
///   struct Person { let name: String; let age: Int }
///
///   let ageLens = Lens<Person, Int>(
///       get: { $0.age },
///       set: { age, person in
///           var p = person
///           p.age = age
///           return p
///       }
///   )
///
///   let person = Person(name: "Alice", age: 30)
///   let older = ageLens.set(31, person)  // Update without mutation
///
///   // Shrinking along lens path: focus on age when searching for minimal failure
///   let shrink = ageLens.shrink(person, predicate: { p in p.age < 100 })
///   ```
///
/// - Note: Lenses are **immutable** - they create new objects rather than mutating.
///   This is essential for property-based testing reproducibility.
///
/// - See Also: ``Prism``, ``Traversal``, ``composition(_:_:)``
public struct Lens<Whole, Part> { ... }
```

---

## 5. Advanced / Specialized APIs

### 5.1 Async Properties

```swift
/// A property that supports asynchronous test conditions.
///
/// Use `AsyncProperty` when the property check involves:
/// - I/O operations (file, network, database)
/// - Asynchronous task execution
/// - Actor-isolated state
/// - Concurrent operation testing
///
/// Inherits all semantics from `Property` but execution is `async`.
/// Concurrency constraints:
/// - Test closure must be `async`
/// - Throws errors are caught as `.error` result
/// - Timeout: 30 seconds per test case (configurable)
///
/// Example use case: Testing a concurrent cache implementation where
/// multiple actors update shared state simultaneously.
///
/// - Parameters:
///   - generator: Source of random test inputs
///   - timeout: Maximum duration per test case. Default: 30 seconds.
///   - test: Async closure to check on each generated input
///
/// - Example:
///   ```swift
///   let property = AsyncProperty(generator: Gen.string()) { input in
///       let result = await fetchFromServer(input)
///       #expect(result.isValid)
///   }
///
///   let outcome = await property.check(count: 50)
///   ```
///
/// - Important: Async closures must handle concurrent execution correctly.
///   Race conditions will be detected by the property tester.
///
/// - See Also: ``Property``, ``PropertyEffect``, ``MainActor``
public struct AsyncProperty<T> { ... }
```

### 5.2 Model-Based Testing

```swift
/// Describes a command in a model-based testing scenario.
///
/// Commands represent abstract operations on the System Under Test (SUT).
/// The property-based tester generates sequences of commands and verifies
/// that the SUT behavior matches an abstract model.
///
/// Example: Testing a concurrent dictionary with commands:
/// - `Set(key, value)`: Model updates dictionary, SUT updates shared state
/// - `Get(key)`: Both return the same value
/// - `Remove(key)`: Both remove the value
///
/// Failures occur when actual behavior diverges from model predictions,
/// detecting race conditions and logic errors.
///
/// - Associated Types:
///   - `Model`: Abstract state type
///   - `SUT`: System Under Test type
///
/// - Requirements:
///   - Implement `run()` to execute on SUT and return observable result
///   - Implement `updateModel()` to update abstract state
///   - Implement `postcondition()` to verify SUT matches model
///
/// - Example:
///   ```swift
///   struct SetCommand: Command {
///       typealias Model = [String: Int]
///       typealias SUT = ConcurrentDict
///
///       let key: String
///       let value: Int
///
///       func run(on sut: SUT) { sut.set(key, value) }
///       func updateModel(_ model: inout Model) { model[key] = value }
///       func postcondition(model: Model, sut: SUT) -> Bool {
///           model[key] == sut.get(key)
///       }
///   }
///   ```
///
/// - See Also: ``ModelBasedProperty``, ``StateMachine``
public protocol Command { ... }
```

---

## 6. Compliance Checklist

### Before Marking Documentation Complete

**Documentation Audit Checklist** (use for final review):

- [ ] All 82 public symbols have DocC comments (verify via `swift build -Xswiftc -warnings-as-errors`)
- [ ] Each symbol has required elements per section 1.2
- [ ] Summary is one sentence, clear, action-oriented
- [ ] Examples are complete, compile, and demonstrate primary use case
- [ ] Mathematical concepts include references (wiki links, papers, etc.)
- [ ] No internal implementation details exposed
- [ ] No broken cross-references (using ``` properly)
- [ ] Consistency: Similar types documented similarly
- [ ] Accessibility: Considered for Voiceover users if applicable
- [ ] Performance: Documented for O(n+) algorithms
- [ ] Threading: Actor isolation documented
- [ ] Related types have "See Also" links

### Code Validation

```bash
# Check for missing documentation (warnings should be 0)
swift build -Xswiftc -warnings-as-errors 2>&1 | grep -i "missing documentation"

# Generate and inspect DocC site locally
swift package generate-documentation
open .build/documentation/docc/Invariant*.doccarchive

# Verify example code compiles
swift build -Xswiftc -warnings-as-errors
```

---

## 7. Style Examples

### 7.1 Good ✅

```swift
/// Generates random strings from the given character set.
///
/// Creates strings of variable length (1-20 characters by default)
/// using the provided character set, with proper shrinking support.
///
/// - Parameters:
///   - characterSet: Character set to draw from (e.g., `.alphanumerics`)
///   - minLength: Minimum string length. Default: 0. Range: 0...100.
///   - maxLength: Maximum string length. Default: 20. Range: 0...1000.
///
/// - Returns: Generator producing strings with built-in shrinking
///
/// - Throws: Never
///
/// - Example:
///   ```swift
///   let gen = Gen.string(characterSet: .alphanumerics, minLength: 1)
///   let property = Property(generator: gen) { str in
///       #expect(!str.isEmpty)
///   }
///   ```
///
/// - See Also: ``Gen.ascii()``, ``Gen.unicode()``
public static func string(
    characterSet: CharacterSet = .alphanumerics,
    minLength: Int = 0,
    maxLength: Int = 20
) -> Gen<String> { ... }
```

### 7.2 Avoid ❌

```swift
/// String generator.  ← Too vague
///
/// Generates strings. This function generates random strings from
/// the provided character set using the internal random implementation. ← Repetitive, vague
/// It uses the Lehmer algorithm internally. ← Implementation detail
///
/// - Parameters:
///   - set: The character set ← What is a "set"? Unclear
///   - min: Min length ← min? Maybe minLength?
///   - max: Max length ← Same unclear abbreviation
///
/// - Note: Thread-safe  ← That should be precondition/requirement
/// - Note: Very fast  ← "Very" is subjective; measure it
///
/// Example: ← Not a Snippet block; won't be formatted correctly
///   let x = string(set: .letters, min: 1, max: 10)
public static func string(set: CharacterSet, min: Int, max: Int) -> Gen<String>
```

---

## 8. Examples by API Category

### Gen Hierarchy

Each generator type should document:
- What it generates (type and constraints)
- Shrinking strategy (how it minimizes counterexamples)
- Performance characteristics (time/space)
- Common use cases

### Property API

Each property type should document:
- When to use (async vs sync, model-based vs property-based)
- Generation strategy
- Failure semantics (what counts as failure)
- Assertion integration

### Coverage API

Each coverage type should document:
- What metric it tracks (branches, paths, mutations, etc.)
- Bias strategy (how it prioritizes generation)
- Reporting format
- Threshold recommendations

---

## 9. Template Maintenance

### When to Update

- [ ] New public symbol added → Add documentation within same commit
- [ ] API renames (per Milestone 0.5) → Update documentation references
- [ ] Functionality changes → Update examples and descriptions
- [ ] User feedback → Clarify ambiguous sections

### Review Process

1. **Self-review**: Against section 1.2 and 6 checklists
2. **Peer review**: Another developer verifies clarity and accuracy
3. **Example validation**: Ensure code snippets compile
4. **DocC build**: `swift package generate-documentation` succeeds
5. **Integration**: Add to CHANGELOG under "Documentation" section

---

## 10. References

### Swift/DocC Resources

- [Apple DocC Guide](https://www.swift.org/documentation/docc)
- [Swift API Guidelines](https://www.swift.org/documentation/api-design-guidelines)
- [Markdown in DocC](https://www.swift.org/documentation/docc/formatting-your-documentation-comments)

### Mathematical/Functional Programming

- [Haskell Functor Laws](https://wiki.haskell.org/Functor)
- [Lens Laws](https://github.com/ekmett/lens/wiki/Overview#laws)
- [Coalgebraic Shrinking](https://dl.acm.org/doi/10.1145/2635868.2635897)
- [Property-Based Testing](https://hypothesis.works/articles/what-is-property-based-testing/)

### InvariantSwift Specific

- [API_AUDIT.md](./API_AUDIT.md) - Complete symbol inventory
- [PUBLIC_API_DESIGN.md](./PUBLIC_API_DESIGN.md) - API organization and stability matrix
- [CHANGELOG.md](../CHANGELOG.md) - Version and feature history

---

**Document Owner**: Architecture Team
**Last Reviewed**: 2026-01-16
**Next Review**: Upon 1.0 release
**Related Issues**: Milestone 0.3, Milestone 0.4
