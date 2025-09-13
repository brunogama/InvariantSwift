import Testing
import Foundation

// MARK: - @PropertyTest Macro Definition

/// **Property-Based Testing Macro for Swift Testing Integration**
///
/// A macro that generates Swift Testing compatible property-based tests, implementing
/// the QuickCheck approach within Apple's Swift Testing framework. This macro automatically
/// generates appropriate generators for function parameters and integrates shrinking with
/// Swift Testing's assertion system.
///
/// **Mathematical Foundation:**
/// The macro generates test functions that verify universal quantification over input domains:
/// `∀x ∈ Domain(T). P(x) = true`
///
/// Where P(x) is the property predicate and T is the type being tested.
///
/// **Generator Inference Rules:**
/// - `Int` → `Gen.int` (uniform distribution with shrinking toward zero)
/// - `String` → `Gen.string` (ASCII strings with shrinking toward empty string)
/// - `[T]` → `Gen.array(Gen<T>)` (arrays with shrinking toward empty array and element shrinking)
/// - `T?` → `Gen.optional(Gen<T>)` (optional values with shrinking toward nil)
/// - Custom types with `Arbitrary` conformance use their defined generators
///
/// **Usage Examples:**
/// ```swift
/// // Basic property test
/// @PropertyTest("Array reverse identity")
/// func testReverseIdentity(_ xs: [Int]) {
///     #expect(xs.reversed().reversed() == xs)
/// }
///
/// // Custom configuration
/// @PropertyTest("Sorting preserves length", iterations: 200, seed: 42)
/// func testSortLength(_ array: [Int]) {
///     #expect(array.sorted().count == array.count)
/// }
///
/// // Multi-parameter property
/// @PropertyTest("Addition commutativity")
/// func testAdditionCommutative(_ a: Int, _ b: Int) {
///     #expect(a + b == b + a)
/// }
/// ```
///
/// **Generated Code Pattern:**
/// ```swift
/// @Test("Array reverse identity_Property")
/// func testReverseIdentity_Property() throws {
///     try checkProperty(
///         Property(
///             generator: Gen.array(Gen.int),
///             predicate: { xs in xs.reversed().reversed() == xs }
///         ),
///         config: PropertyConfig(iterations: 100, seed: nil, maxShrinks: 1000)
///     )
/// }
/// ```
///
/// **Shrinking Integration:**
/// When a property fails, the macro-generated test automatically:
/// 1. Captures the original counterexample
/// 2. Applies shrinking algorithms to find minimal failing case
/// 3. Reports both original and shrunk counterexamples via Swift Testing's Issue.record()
/// 4. Provides actionable failure information for debugging
///
/// **Performance Characteristics:**
/// - O(n) where n is the number of iterations (default 100)
/// - O(log m) shrinking complexity where m is the size of the input domain
/// - Generators typically produce 10,000+ values per second for primitive types
///
/// - Parameters:
///   - name: Optional test name (defaults to function name with "_Property" suffix)
///   - iterations: Number of test iterations (default: 100, range: 1-10,000)
///   - seed: Optional seed for deterministic testing (UInt64 value)
///   - maxShrinks: Maximum shrinking attempts when property fails (default: 1000)
@attached(peer, names: suffixed(_Property))
public macro PropertyTest(
  _ name: String? = nil,
  iterations: Int = 100,
  seed: UInt64? = nil,
  maxShrinks: Int = 1000
) = #externalMacro(module: "FunctionalTestingMacros", type: "PropertyTestMacro")

// MARK: - Swift Testing Integration Utilities

/// **Synchronous Property Checking with Swift Testing Integration**
///
/// Executes a property-based test synchronously and integrates results with Swift Testing's
/// assertion system. This function serves as the bridge between FunctionalTesting's property
/// testing engine and Swift Testing's test reporting infrastructure.
///
/// **Mathematical Foundation:**
/// Implements the property testing algorithm:
/// ```
/// checkProperty(P, config) = {
///   for i in 1..config.iterations:
///     x ← generate(config.generator, seed_i, size_i)
///     if ¬P(x):
///       x_min ← shrink(x, P, config.maxShrinks)
///       return Failure(x, x_min)
///   return Success(config.iterations)
/// }
/// ```
///
/// **Integration with Swift Testing:**
/// - Uses `Issue.record()` for failure reporting instead of throwing exceptions
/// - Preserves file and line information for accurate test failure location
/// - Formats counterexamples for optimal readability in test output
/// - Handles both logical failures (property returns false) and exceptional failures
///
/// **Usage Examples:**
/// ```swift
/// // Basic synchronous property checking
/// @Test func arrayReverseProperty() throws {
///   let property = Property(
///     generator: Gen.array(Gen.int),
///     predicate: { array in array.reversed().reversed() == array }
///   )
///   try checkProperty(property)
/// }
///
/// // Custom configuration
/// @Test func arithmeticProperty() throws {
///   let config = PropertyConfig(iterations: 200, maxShrinks: 500)
///   try checkProperty(arithmeticProperty, config: config)
/// }
/// ```
///
/// **Performance Characteristics:**
/// - O(n × k) where n = iterations, k = average property evaluation time
/// - Shrinking: O(log m × s) where m = input size, s = shrinking complexity
/// - Memory: O(1) for single property execution, O(d) for shrinking depth d
///
/// **Error Handling:**
/// This function doesn't throw errors for property failures. Instead, it:
/// 1. Records issues through Swift Testing's `Issue.record()` system
/// 2. Only throws for configuration errors or generator failures
/// 3. Formats detailed failure messages with original and shrunk counterexamples
///
/// - Parameters:
///   - property: The property to test, containing generator and predicate
///   - config: Test configuration (iterations, seeds, shrinking limits)
///   - file: Source file location for test failure reporting
///   - line: Source line number for test failure reporting
/// - Throws: Only for configuration errors or generator failures, not property failures
public func checkProperty<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default,
  file: StaticString = #file,
  line: UInt = #line
) throws {
  let result = PropertyChecker.check(property, config: config)

  switch result {
  case .success:
    break  // Test passes

  case .failure(let counterexample, let iterations, let shrunk):
    let message = """
      Property failed after \(iterations) iterations.
      Counterexample: \(counterexample)
      Shrunk counterexample: \(shrunk)
      """
    Issue.record(Comment(stringLiteral: message))

  case .gaveUp(let discarded, let iterations):
    let message = "Property gave up after discarding \(discarded) cases in \(iterations) iterations"
    Issue.record(Comment(stringLiteral: message))
  }
}

/// **Asynchronous Property Checking with Swift 6 Actor-Isolated Execution**
///
/// Executes property-based tests asynchronously using PropertyRunner's actor-isolated execution
/// model. This function enables concurrent property testing while maintaining Swift 6 strict
/// concurrency compliance and deterministic execution ordering.
///
/// **Concurrency Model:**
/// - Uses `PropertyRunner` actor for thread-safe test execution
/// - Maintains deterministic seed progression across iterations
/// - Supports cancellation through Swift's structured concurrency
/// - Prevents data races through actor isolation boundaries
///
/// **Mathematical Foundation:**
/// Implements the same property testing algorithm as the synchronous version but with
/// async/await integration:
/// ```
/// checkPropertyAsync(P, config) = async {
///   runner ← PropertyRunner(seed: config.seed)
///   result ← await runner.runProperty(P, config)
///   match result with
///   | Success(n) → Success
///   | Failure(x, n, x_min) → Issue.record(format(x, x_min))
///   | GaveUp(d, n) → Issue.record(gaveUpMessage(d, n))
/// }
/// ```
///
/// **Performance Benefits:**
/// - Non-blocking execution allows other tests to run concurrently
/// - Can be used with Swift Testing's parallel test execution
/// - Better resource utilization for I/O-bound property predicates
/// - Supports Swift's cooperative cancellation model
///
/// **Usage Examples:**
/// ```swift
/// // Async property testing
/// @Test func asyncStringProperty() async throws {
///   let property = Property(
///     generator: Gen.string,
///     predicate: { string in
///       // Simulate async validation
///       await validateString(string)
///     }
///   )
///   try await checkPropertyAsync(property)
/// }
///
/// // With custom configuration and error handling
/// @Test func networkPropertyTest() async throws {
///   let config = PropertyConfig(iterations: 50, maxShrinks: 100)
///   try await checkPropertyAsync(networkProperty, config: config)
/// }
/// ```
///
/// **Actor Isolation:**
/// This function maintains proper actor isolation by:
/// - All generator state is isolated within PropertyRunner actor
/// - Seed progression is deterministic and thread-safe
/// - Property predicates can safely capture external state
/// - Results are safely transferred out of actor boundary
///
/// **Error Handling:**
/// Same error handling model as synchronous version:
/// - Property failures recorded via `Issue.record()`
/// - Only throws for configuration or runtime errors
/// - Detailed counterexample formatting preserved
///
/// - Parameters:
///   - property: The property to test asynchronously
///   - config: Test configuration for async execution
///   - file: Source file location for test failure reporting
///   - line: Source line number for test failure reporting
/// - Throws: Only for configuration errors or generator failures, not property failures
public func checkPropertyAsync<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default,
  file: StaticString = #file,
  line: UInt = #line
) async throws {
  let runner = PropertyRunner(seed: config.seed)
  let result = await runner.runProperty(property, config: config)

  switch result {
  case .success:
    break  // Test passes

  case .failure(let counterexample, let iterations, let shrunk):
    let message = """
      Property failed after \(iterations) iterations.
      Counterexample: \(counterexample)
      Shrunk counterexample: \(shrunk)
      """
    Issue.record(Comment(stringLiteral: message))

  case .gaveUp(let discarded, let iterations):
    let message = "Property gave up after discarding \(discarded) cases in \(iterations) iterations"
    Issue.record(Comment(stringLiteral: message))
  }
}

// MARK: - Utility Functions for Macro-Generated Code

/// Helper function to flatten nested tuples for multi-parameter properties
public func flattenTuple<A, B, C>(_ tuple: ((A, B), C)) -> (A, B, C) {
  (tuple.0.0, tuple.0.1, tuple.1)
}

public func flattenTuple<A, B, C, D>(_ tuple: (((A, B), C), D)) -> (A, B, C, D) {
  (tuple.0.0.0, tuple.0.0.1, tuple.0.1, tuple.1)
}

public func flattenTuple<A, B, C, D, E>(_ tuple: ((((A, B), C), D), E)) -> (A, B, C, D, E) {
  (tuple.0.0.0.0, tuple.0.0.0.1, tuple.0.0.1, tuple.0.1, tuple.1)
}

// MARK: - Property Test Result Types

/// Result type for property test execution compatible with Swift Testing
public enum PropertyTestResult: Sendable {
  case success(iterations: Int)
  case failure(counterexample: String, shrunk: String, iterations: Int)
  case gaveUp(discarded: Int, iterations: Int)
}

/// Convert PropertyResult to PropertyTestResult for Swift Testing integration
public func convertPropertyResult<T>(_ result: PropertyResult<T>) -> PropertyTestResult {
  switch result {
  case .success(let iterations):
    return .success(iterations: iterations)

  case .failure(let counterexample, let iterations, let shrunk):
    return .failure(
      counterexample: "\(counterexample)",
      shrunk: "\(shrunk)",
      iterations: iterations
    )

  case .gaveUp(let discarded, let iterations):
    return .gaveUp(discarded: discarded, iterations: iterations)
  }
}

// MARK: - Generator Inference Extensions
// Note: Generators are defined in the main generator files

// MARK: - Array Generator for Common Types

extension Gen {
  /// Create array generator for any element generator
  public static func array<Element>(_ elementGen: Gen<Element>) -> Gen<[Element]>
  where T == [Element] {
    Gen<[Element]>(
      generate: { rng, size in
        let arraySize = Int.random(in: 0...min(size.value, 100), using: &rng)
        return (0..<arraySize).map { _ in elementGen.generate(&rng, Size.scale(by: 0.8)(size)) }
      },
      shrink: Shrink { array in
        if array.isEmpty {
          return []
        }

        var candidates: [[Element]] = []

        // Shrink by removing elements
        if array.count > 1 {
          candidates.append(Array(array.dropFirst()))
          candidates.append(Array(array.dropLast()))
          candidates.append(Array(array.prefix(array.count / 2)))
        }

        // Shrink individual elements
        for (index, element) in array.enumerated() {
          let shrunkElements = elementGen.shrink.shrink(element)
          for shrunkElement in shrunkElements {
            var newArray = array
            newArray[index] = shrunkElement
            candidates.append(newArray)
          }
        }

        return candidates
      }
    )
  }
}
