import Testing
import Foundation
import InvariantSwiftCore
import InvariantSwift

// MARK: - Swift Testing Integration Utilities

/// Execute a property-based test and record results with Swift Testing's issue system.
///
/// This function runs a property-based test and integrates the outcome with Swift Testing's
/// failure reporting. Use this when you want to manually run a property test from within
/// a Swift Testing `@Test` function (the ``PropertyTest`` macro handles this automatically).
///
/// **Result Handling:**
/// - **.success**: Test passes; no issues recorded
/// - **.failure**: Records an issue with the counterexample and shrunk minimal case
/// - **.gaveUp**: Records an issue indicating insufficient test coverage
///   (suggests predicate is too restrictive)
///
/// **Integration with Swift Testing:**
/// Results are recorded using Swift Testing's `Issue.record()` API, making them
/// visible in test reports and CI logs. Failed properties appear as test failures.
///
/// **Configuration:**
/// The `PropertyConfig` controls testing behavior:
/// - `iterations`: Number of test cases (default: 100)
/// - `maxShrinks`: Maximum shrinking attempts (default: 1000)
/// - `maxDiscarded`: Maximum discarded cases before giving up (default: 100)
/// - `seed`: Optional seed for determinism (default: nil)
///
/// **Performance Characteristics:**
/// - **Time**: O(iterations * shrinkingCost) in worst case
/// - **Space**: O(1) beyond the property's generator state
///
/// **Thread Safety:**
/// Safe to call from async test contexts; issue recording is thread-safe.
///
/// - Parameters:
///   - property: The ``Property`` to check (combines generator and test closure)
///   - config: Configuration controlling test execution behavior
///   - file: Source file location (captured from call site via #file)
///   - line: Source line number (captured from call site via #line)
///
/// - Throws: Does not throw (all errors are recorded as issues)
///
/// - Example:
///   ```swift
///   @Test
///   func testAdditionCommutativity() throws {
///       let gen = Gen.tuple(Gen.integer(in: 0..<100), Gen.integer(in: 0..<100))
///       let property = Property(generator: gen) { (a, b) in
///           #expect(a + b == b + a)
///       }
///
///       try checkProperty(property)
///   }
///   ```
///
/// - Note: Important: For most use cases, prefer the ``PropertyTest`` macro,
///   which handles this integration automatically. Use `checkProperty` only
///   when you need manual control or custom generator setup.
///
/// - See Also: ``Property``, ``PropertyTest``, ``checkPropertyAsync(_:config:file:line:)``
public func checkProperty<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  try executeGeneratedPropertyTest(
    property,
    config: config,
    testName: currentPropertyTestName(),
    labels: PropertyTestContext.current?.labels ?? [],
    file: file,
    line: line
  )
}

/// Asynchronously execute a property-based test with integration to Swift Testing.
///
/// This is the async variant of ``checkProperty(_:config:file:line:)``, suitable for properties
/// that involve asynchronous operations (I/O, concurrent tasks, actor-isolated code).
///
/// **When to Use:**
/// Use `checkPropertyAsync` when your property test involves:
/// - Asynchronous function calls (network, file I/O, database)
/// - Actor-isolated code or concurrent operations
/// - Tasks or async sequences
/// - Time-dependent behavior
///
/// **Async Semantics:**
/// Must be called from an async context (e.g., inside an async `@Test` function).
/// Each test iteration runs sequentially within the test task.
///
/// **Result Handling:**
/// Same as ``checkProperty(_:config:file:line:)`` — results are recorded as Swift Testing issues.
/// Failures include both the original counterexample and the shrunk minimal case.
///
/// **Performance:**
/// Async property testing is slower than synchronous due to task overhead.
/// Consider:
/// - Running fewer iterations (`config.iterations = 50`)
/// - Using smaller shrink bounds (`config.maxShrinks = 100`)
/// - Batching async operations where possible
///
/// **Availability:**
/// Requires macOS 10.15 or later for async/await support.
///
/// - Parameters:
///   - property: The ``Property`` to check asynchronously
///   - config: Configuration (same as ``checkProperty(_:config:file:line:)``)
///   - file: Source file location
///   - line: Source line number
///
/// - Throws: Does not throw (errors are recorded as issues)
///
/// - Example (Simple Async Property):
///   ```swift
///   @Test
///   func testAsyncStringFetch() async throws {
///       let gen = Gen.string()
///       let property = Property(generator: gen) { url in
///           let result = await fetchString(url)
///           #expect(result.isEmpty == false)
///       }
///
///       try await checkPropertyAsync(property)
///   }
///   ```
///
/// - Example (Actor-Isolated Code):
///   ```swift
///   actor Counter {
///       private var count: Int = 0
///       func increment() { count += 1 }
///       func value() -> Int { count }
///   }
///
///   @Test
///   func testActorIncrement() async throws {
///       let counter = Counter()
///       let gen = Gen.integer(in: 1..<100)
///       let property = Property(generator: gen) { n in
///           for _ in 0..<n {
///               await counter.increment()
///           }
///           let finalCount = await counter.value()
///           #expect(finalCount == n)
///       }
///
///       try await checkPropertyAsync(property)
///   }
///   ```
///
/// - Note: Important: Keep test closures short and fast. Long-running async operations
///   (e.g., real network requests) are typically unsuitable for property testing.
///   Mock or use in-process async operations instead.
///
/// - See Also: ``checkProperty(_:config:file:line:)``, ``Property``, ``PropertyRunner``
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func checkPropertyAsync<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  try await executeGeneratedPropertyTestAsync(
    property,
    config: config,
    testName: currentPropertyTestName(),
    labels: PropertyTestContext.current?.labels ?? [],
    file: file,
    line: line
  )
}

// MARK: - Utility Functions for Macro-Generated Code

// swiftlint:disable:next orphaned_doc_comment
/// Helper function to flatten nested tuples for multi-parameter properties
// swiftlint:disable:next large_tuple
public func flattenTuple<A, B, C>(_ tuple: ((A, B), C)) -> (A, B, C) {
  (tuple.0.0, tuple.0.1, tuple.1)
}

// swiftlint:disable:next large_tuple
public func flattenTuple<A, B, C, D>(_ tuple: (((A, B), C), D)) -> (A, B, C, D) {
  (tuple.0.0.0, tuple.0.0.1, tuple.0.1, tuple.1)
}

// swiftlint:disable:next large_tuple
public func flattenTuple<A, B, C, D, E>(_ tuple: ((((A, B), C), D), E)) -> (A, B, C, D, E) {
  (tuple.0.0.0.0, tuple.0.0.0.1, tuple.0.0.1, tuple.0.1, tuple.1)
}

// MARK: - Property Test Result Types

// swiftlint:disable:next orphaned_doc_comment
/// Result of executing a property-based test with details for logging and reporting.
///
/// `PropertyTestResult` captures the outcome of a property-based test execution,
/// compatible with Swift Testing's result system. Used internally by the property
/// testing framework and available for custom test runners.
///
/// **Result Cases:**
/// - **.success**: Property held for all iterations; includes iteration count
/// - **.failure**: Property failed; includes both original and minimized counterexamples
/// - **.gaveUp**: Property was discarded too often; indicates insufficient test coverage
///
/// **String Representation:**
/// Counterexamples are stringified for display in test output. For complex types,
/// implement `CustomStringConvertible` to get readable representations.
///
/// **Sendable Conformance:**
/// All cases are sendable, allowing safe transmission across task boundaries.
/// Useful for concurrent test runners and distributed testing.
///
/// - Cases:
///   - `.success(iterations:)`: Test passed for all generated inputs.
///     - `iterations`: Number of successful test iterations
///   - `.failure(counterexample:shrunk:iterations:)`: Test failed on a specific input.
///     - `counterexample`: String representation of the original failing input
///     - `shrunk`: String representation of the minimized failing input
///     - `iterations`: Iteration number when failure occurred
///   - `.gaveUp(discarded:iterations:)`: Property was too restrictive.
///     - `discarded`: Number of generated values that were discarded
///     - `iterations`: Total iterations before giving up
///
/// - Example:
///   ```swift
///   switch result {
///   case .success(let iterations):
// swiftlint:disable:next no_print
///       print("Passed all \(iterations) iterations")
///   case .failure(let original, let shrunk, let iteration):
// swiftlint:disable:next no_print
///       print("Failed at iteration \(iteration)")
// swiftlint:disable:next no_print
///       print("Original: \(original)")
// swiftlint:disable:next no_print
///       print("Minimized: \(shrunk)")
///   case .gaveUp(let discarded, let iterations):
// swiftlint:disable:next no_print
///       print("Gave up: \(discarded) discarded in \(iterations) iterations")
///   }
///   ```
///
/// - Note: The shrunk counterexample is typically simpler and smaller than the original,
///   making it easier to debug. When reporting failures, always include the shrunk value.
///
/// - See Also: ``convertPropertyResult(_:)``
public enum PropertyTestResult: Sendable {
  /// Test passed for all generated inputs.
  case success(iterations: Int)

  /// Test failed; includes original and shrunk counterexamples.
  case failure(counterexample: String, shrunk: String, iterations: Int)

  /// Test gave up due to too many discarded cases.
  case gaveUp(discarded: Int, iterations: Int)
}

// swiftlint:disable:next orphaned_doc_comment
/// Convert internal property results to Swift Testing-compatible result format.
///
/// Transforms a raw ``PropertyResult`` (from the test framework) into a ``PropertyTestResult``
/// (for Swift Testing integration). Primarily used internally by test macros and runners,
/// but available for custom test execution.
///
/// **Conversion Details:**
/// - Generic success/failure cases are preserved with all metadata
/// - Counterexample values are stringified for display purposes
/// - Iteration counts and discard counts are maintained
///
/// **Type Conversion:**
/// The input `PropertyResult<T>` carries the concrete test input type `T`.
/// The output `PropertyTestResult` converts values to strings for display,
/// allowing the result to be serialized and transmitted safely.
///
/// - Parameter result: A ``PropertyResult`` from the framework
/// - Returns: A ``PropertyTestResult`` ready for Swift Testing integration
///
/// - Complexity: O(n) where n is the size of counterexample values (for stringification)
///
/// - Example:
///   ```swift
///   let propertyResult = PropertyResult.failure(value, 50, minimized)
///   let testResult = convertPropertyResult(propertyResult)
///   switch testResult {
///   case .failure(let original, let shrunk, let iter):
// swiftlint:disable:next no_print
///       print("Failed at iteration \(iter)")
// swiftlint:disable:next no_print
///       print("Original: \(original), Minimized: \(shrunk)")
///   default:
///       break
///   }
///   ```
///
/// - See Also: ``PropertyResult``, ``PropertyTestResult``
public func convertPropertyResult<T>(_ result: PropertyResult<T>) -> PropertyTestResult {
  switch result {
  case .success(let iterations):
    return .success(iterations: iterations)

  case .failure(let counterexample, let iterations, let shrunk, _, _):
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
        return (0..<arraySize).map { _ in elementGen.generate(&rng, size.scaled(by: 0.8)) }
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

// MARK: - ClassifyingProperty Integration

/// Execute a classifying property-based test with classification tracking.
///
/// This function runs a property test with classification support and integrates
/// the outcome with Swift Testing's failure reporting. Classification reports
/// are included in both passing and failing test output.
///
/// - Parameters:
///   - property: The ``ClassifyingProperty`` to check
///   - config: Configuration controlling test execution behavior
///   - file: Source file location (captured from call site via #file)
///   - line: Source line number (captured from call site via #line)
///
/// - Throws: Does not throw (all errors are recorded as issues)
///
/// - Example:
///   ```swift
///   @Test
///   func testWithClassification() async throws {
///       let property = Property(generator: Gen.int) { n in n >= 0 }
///         .cover(50, when: { $0 > 0 }, label: "positive")
///
///       try await checkProperty(property)
///   }
///   ```
public func checkProperty<T: Sendable>(
  _ property: ClassifyingProperty<T>,
  config: PropertyConfig = .default,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  let runner = PropertyRunner(seed: config.seed)
  let result = await runner.runClassifyingProperty(property, config: config)

  switch result.result {
  case .success:
    let report = result.classification.format()
    attachClassificationReport(report, file: file, line: line)

  case .failure:
    if let failureReport = FailureReport.from(result, config: config) {
      let reporter = FailureReporter(verbose: true)
      reporter.recordFailure(
        failureReport,
        labels: PropertyTestContext.current?.labels ?? [],
        file: file,
        line: line
      )
    }

  case .gaveUp(let discarded, let iterations):
    recordPropertyGiveUpIssue(
      testName: currentPropertyTestName(fallback: "ClassifyingProperty"),
      discarded: discarded,
      iterations: iterations,
      seed: config.seed?.rawValue ?? PropertyTestContext.current?.seed,
      context: PropertyIssueContext(
        labels: PropertyTestContext.current?.labels ?? [],
        file: file,
        line: line
      )
    )
  }
}
