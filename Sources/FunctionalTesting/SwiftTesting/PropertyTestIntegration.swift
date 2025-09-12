import Testing
import Foundation

// MARK: - @PropertyTest Macro Definition

/// A macro that generates Swift Testing compatible property-based tests.
///
/// Usage:
/// ```swift
/// @PropertyTest("Array reverse identity")
/// func testReverseIdentity(_ xs: [Int]) {
///     #expect(xs.reversed().reversed() == xs)
/// }
/// ```
///
/// The macro will generate a corresponding `@Test` function that:
/// 1. Creates appropriate generators for the function parameters
/// 2. Runs the property test with the specified number of iterations
/// 3. Handles failures by shrinking counterexamples
/// 4. Integrates with Swift Testing's assertion system
///
/// - Parameters:
///   - name: Optional test name (defaults to function name)
///   - iterations: Number of test iterations (default: 100)
///   - seed: Optional seed for deterministic testing
///   - maxShrinks: Maximum shrinking attempts (default: 1000)
@attached(peer, names: suffixed(_Property))
public macro PropertyTest(
  _ name: String? = nil,
  iterations: Int = 100,
  seed: UInt64? = nil,
  maxShrinks: Int = 1000
) = #externalMacro(module: "FunctionalTestingMacros", type: "PropertyTestMacro")

// MARK: - Swift Testing Integration Utilities

/// Check a property and integrate results with Swift Testing
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

/// Async version of checkProperty for concurrent property testing
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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
  return (tuple.0.0, tuple.0.1, tuple.1)
}

public func flattenTuple<A, B, C, D>(_ tuple: (((A, B), C), D)) -> (A, B, C, D) {
  return (tuple.0.0.0, tuple.0.0.1, tuple.0.1, tuple.1)
}

public func flattenTuple<A, B, C, D, E>(_ tuple: ((((A, B), C), D), E)) -> (A, B, C, D, E) {
  return (tuple.0.0.0.0, tuple.0.0.0.1, tuple.0.0.1, tuple.0.1, tuple.1)
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
    return Gen<[Element]>(
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
