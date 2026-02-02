import Testing
import Foundation
@testable import InvariantCore
@testable import InvariantSwift

// MARK: - Test Utilities Framework for 99%+ Code Coverage (Task 11)

/// Comprehensive test utilities framework for property-based testing
/// Provides reusable components, assertions, and test patterns
public struct TestUtilities {

  // MARK: - Property Testing Helpers

  /// Helper for running property tests with consistent error handling
  public static func runProperty<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = PropertyConfig.default,
    expectation: PropertyExpectation = .success,
    file: StaticString = #file,
    line: UInt = #line
  ) -> PropertyResult<T> {
    let result = runPropertySynchronously(property, config: config)

    // Validate expectation
    switch (result, expectation) {
    case (.success, .success):
      break  // Expected
    case (.failure, .failure):
      break  // Expected
    case (.gaveUp, .gaveUp):
      break  // Expected
    case (.success, .failure):
      Issue.record("Expected failure but got success")

    case (.failure, .success):
      Issue.record("Expected success but got failure")

    case (.gaveUp, .success):
      Issue.record("Expected success but property gave up")

    case (.success, .gaveUp):
      Issue.record("Expected gaveUp but got success")

    case (.failure, .gaveUp):
      Issue.record("Expected gaveUp but got failure")

    case (.gaveUp, .failure):
      Issue.record("Expected failure but property gave up")
    }

    return result
  }

  /// Helper for running async property tests
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public static func runPropertyAsync<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = PropertyConfig.default,
    expectation: PropertyExpectation = .success,
    file: StaticString = #file,
    line: UInt = #line
  ) async -> PropertyResult<T> {
    let runner = PropertyRunner(seed: config.seed)
    let result = await runner.runProperty(property, config: config)

    // Validate expectation
    switch (result, expectation) {
    case (.success, .success):
      break  // Expected
    case (.failure, .failure):
      break  // Expected
    case (.gaveUp, .gaveUp):
      break  // Expected
    default:
      Issue.record("Async property expectation not met: got \(result), expected \(expectation)")
    }

    return result
  }

  // MARK: - Custom Assertions

  /// Assert that a property result is successful with expected iterations
  public static func expectSuccess<T>(
    _ result: PropertyResult<T>,
    iterations: Int,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    switch result {
    case .success(let actualIterations):
      #expect(
        actualIterations == iterations,
        "Expected \(iterations) iterations, got \(actualIterations)"
      )

    case .failure(let counterexample, let iter, let shrunk, _, _):
      Issue.record(
        "Expected success but got failure: counterexample=\(counterexample), iterations=\(iter), shrunk=\(shrunk)"
      )

    case .gaveUp(let discarded, let iter):
      Issue.record(
        "Expected success but property gave up: discarded=\(discarded), iterations=\(iter)"
      )
    }
  }

  /// Assert that a property result is a failure with proper shrinking
  public static func expectFailure<T: Comparable>(
    _ result: PropertyResult<T>,
    counterexamplePredicate: (T) -> Bool = { _ in true },
    shrinkingPredicate: (T, T) -> Bool = { shrunk, original in shrunk <= original },
    file: StaticString = #file,
    line: UInt = #line
  ) {
    switch result {
    case .failure(let counterexample, let iterations, let shrunk, _, _):
      #expect(iterations > 0, "Should have attempted at least one iteration")
      #expect(
        counterexamplePredicate(counterexample),
        "Counterexample \(counterexample) does not satisfy predicate"
      )
      #expect(
        shrinkingPredicate(shrunk, counterexample),
        "Shrinking failed: shrunk=\(shrunk), original=\(counterexample)"
      )

    case .success(let iterations):
      Issue.record("Expected failure but got success with \(iterations) iterations")

    case .gaveUp(let discarded, let iterations):
      Issue.record(
        "Expected failure but property gave up: discarded=\(discarded), iterations=\(iterations)"
      )
    }
  }

  /// Assert that a property gave up due to filtering
  public static func expectGaveUp<T>(
    _ result: PropertyResult<T>,
    minDiscarded: Int = 1,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    switch result {
    case .gaveUp(let discarded, let iterations):
      #expect(
        discarded >= minDiscarded,
        "Expected at least \(minDiscarded) discarded, got \(discarded)"
      )
      #expect(iterations >= 0, "Iterations should be non-negative")

    case .success(let iterations):
      Issue.record("Expected gaveUp but got success with \(iterations) iterations")

    case .failure(let counterexample, let iterations, let shrunk, _, _):
      Issue.record(
        "Expected gaveUp but got failure: counterexample=\(counterexample), iterations=\(iterations), shrunk=\(shrunk)"
      )
    }
  }

  // MARK: - Performance Testing Utilities

  /// Measure execution time of property testing
  public static func measurePropertyExecution<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = PropertyConfig.default,
    maxDuration: TimeInterval = 10.0,
    file: StaticString = #file,
    line: UInt = #line
  ) -> (result: PropertyResult<T>, duration: TimeInterval) {
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = runPropertySynchronously(property, config: config)
    let duration = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      duration <= maxDuration,
      "Property execution took \(duration)s, exceeds maximum \(maxDuration)s"
    )

    return (result, duration)
  }

  /// Measure memory usage during property testing
  public static func measurePropertyMemory<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = PropertyConfig.default,
    file: StaticString = #file,
    line: UInt = #line
  ) -> (result: PropertyResult<T>, memoryInfo: MemoryInfo) {
    let memoryBefore = getCurrentMemoryUsage()
    let result = runPropertySynchronously(property, config: config)
    let memoryAfter = getCurrentMemoryUsage()

    let memoryInfo = MemoryInfo(
      before: memoryBefore,
      after: memoryAfter,
      delta: Int64(memoryAfter) - Int64(memoryBefore)
    )

    return (result, memoryInfo)
  }

  // MARK: - Generator Testing Utilities

  /// Validate generator produces values in expected range
  public static func validateGeneratorRange<T: Comparable>(
    _ generator: Gen<T>,
    range: ClosedRange<T>,
    samples: Int = 100,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
    let size = Size(value: 10)

    for _ in 0..<samples {
      let value = generator.generate(&rng, size)
      #expect(
        range.contains(value),
        "Generated value \(value) is outside expected range \(range)"
      )
    }
  }

  /// Validate generator produces diverse values
  public static func validateGeneratorDiversity<T: Hashable>(
    _ generator: Gen<T>,
    samples: Int = 100,
    minUniqueValues: Int = 10,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 123))
    let size = Size(value: 20)

    var uniqueValues: Set<T> = []
    for _ in 0..<samples {
      let value = generator.generate(&rng, size)
      uniqueValues.insert(value)
    }

    #expect(
      uniqueValues.count >= minUniqueValues,
      "Generator produced only \(uniqueValues.count) unique values, expected at least \(minUniqueValues)"
    )
  }

  /// Validate shrinking produces smaller values
  public static func validateShrinking<T: Comparable>(
    _ generator: Gen<T>,
    samples: Int = 50,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 456))
    let size = Size(value: 50)

    for _ in 0..<samples {
      let original = generator.generate(&rng, size)
      let shrunkCandidates = generator.shrink.shrink(original)

      for shrunk in shrunkCandidates.prefix(10) {  // Check first 10 candidates
        #expect(
          shrunk <= original,
          "Shrunk value \(shrunk) should be <= original \(original)"
        )
      }
    }
  }

  // MARK: - Configuration Testing Utilities

  /// Test property with various configuration combinations
  public static func testPropertyWithConfigurations<T: Sendable>(
    _ property: Property<T>,
    configurations: [PropertyConfig],
    file: StaticString = #file,
    line: UInt = #line
  ) -> [PropertyResult<T>] {
    var results: [PropertyResult<T>] = []

    for config in configurations {
      let result = runPropertySynchronously(property, config: config)
      results.append(result)
    }

    return results
  }

  /// Generate test configurations for comprehensive testing
  public static func generateTestConfigurations() -> [PropertyConfig] {
    [
      PropertyConfig(iterations: 1, maxShrinks: 0, maxDiscarded: 1, seed: Seed(value: 1)),
      PropertyConfig(iterations: 10, maxShrinks: 10, maxDiscarded: 10, seed: Seed(value: 42)),
      PropertyConfig(iterations: 100, maxShrinks: 100, maxDiscarded: 100, seed: Seed(value: 12345)),
      PropertyConfig(
        iterations: 1000,
        maxShrinks: 500,
        maxDiscarded: 1000,
        seed: Seed(value: 98765)
      ),
      PropertyConfig(iterations: 50, maxShrinks: 0, maxDiscarded: 200, seed: nil),  // No shrinking
      PropertyConfig(iterations: 200, maxShrinks: 2000, maxDiscarded: 50, seed: nil),  // High shrinking
    ]
  }

  // MARK: - Deterministic Testing Utilities

  /// Run property with same seed multiple times to verify deterministic behavior
  public static func verifyDeterministicBehavior<T: Sendable & Equatable>(
    _ property: Property<T>,
    config: PropertyConfig,
    repetitions: Int = 3,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    guard config.seed != nil else {
      Issue.record("Deterministic testing requires a specific seed")
      return
    }

    var results: [PropertyResult<T>] = []

    for _ in 0..<repetitions {
      let result = runPropertySynchronously(property, config: config)
      results.append(result)
    }

    // Verify all results are identical
    let firstResult = results[0]
    for (index, result) in results.enumerated().dropFirst() {
      let areEqual = PropertyTestUtils.compareResults(firstResult, result)
      #expect(
        areEqual,
        "Deterministic test repetition \(index) differs from first result"
      )
    }
  }

  // MARK: - Concurrent Testing Utilities

  /// Run multiple properties concurrently and verify results
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  public static func runPropertiesConcurrently<T: Sendable>(
    _ properties: [Property<T>],
    config: PropertyConfig = PropertyConfig.default,
    file: StaticString = #file,
    line: UInt = #line
  ) async -> [PropertyResult<T>] {
    await withTaskGroup(of: PropertyResult<T>.self, returning: [PropertyResult<T>].self) {
      group in
      for property in properties {
        group.addTask {
          let runner = PropertyRunner(seed: config.seed)
          return await runner.runProperty(property, config: config)
        }
      }

      var results: [PropertyResult<T>] = []
      for await result in group {
        results.append(result)
      }
      return results
    }
  }

  // MARK: - Statistical Testing Utilities

  /// Analyze property test results for statistical patterns
  public static func analyzeResults<T>(
    _ results: [PropertyResult<T>],
    file: StaticString = #file,
    line: UInt = #line
  ) -> ResultAnalysis {
    let successCount = results.filter {
      if case .success = $0 { return true }
      return false
    }.count
    let failureCount = results.filter {
      if case .failure = $0 { return true }
      return false
    }.count
    let gaveUpCount = results.filter {
      if case .gaveUp = $0 { return true }
      return false
    }.count

    let totalIterations = results.compactMap { result -> Int? in
      switch result {
      case .success(let iter): return iter
      case .failure(_, let iter, _, _, _): return iter
      case .gaveUp(_, let iter): return iter
      }
    }.reduce(0, +)

    return ResultAnalysis(
      totalTests: results.count,
      successCount: successCount,
      failureCount: failureCount,
      gaveUpCount: gaveUpCount,
      totalIterations: totalIterations,
      averageIterations: results.isEmpty ? 0 : Double(totalIterations) / Double(results.count)
    )
  }
}

// MARK: - Supporting Types

/// Expected outcome for property tests
public enum PropertyExpectation {
  case success
  case failure
  case gaveUp
}

/// Memory usage information
public struct MemoryInfo {
  public let before: UInt64
  public let after: UInt64
  public let delta: Int64

  public var deltaMB: Double {
    Double(delta) / 1024.0 / 1024.0
  }
}

/// Statistical analysis of property test results
public struct ResultAnalysis {
  public let totalTests: Int
  public let successCount: Int
  public let failureCount: Int
  public let gaveUpCount: Int
  public let totalIterations: Int
  public let averageIterations: Double

  public var successRate: Double {
    totalTests > 0 ? Double(successCount) / Double(totalTests) : 0.0
  }

  public var failureRate: Double {
    totalTests > 0 ? Double(failureCount) / Double(totalTests) : 0.0
  }

  public var gaveUpRate: Double {
    totalTests > 0 ? Double(gaveUpCount) / Double(totalTests) : 0.0
  }
}

// MARK: - Helper Functions

/// Get current memory usage (simplified version)
private func getCurrentMemoryUsage() -> UInt64 {
  var info = mach_task_basic_info()
  var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

  let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
      task_info(
        mach_task_self_,
        task_flavor_t(MACH_TASK_BASIC_INFO),
        $0,
        &count
      )
    }
  }

  if kerr == KERN_SUCCESS {
    return info.resident_size
  }
  return 0
}

// MARK: - Property Test Utils

private enum PropertyTestUtils {
  static func compareResults<T: Equatable>(
    _ lhs: PropertyResult<T>,
    _ rhs: PropertyResult<T>
  ) -> Bool {
    switch (lhs, rhs) {
    case (.success(let iter1), .success(let iter2)):
      return iter1 == iter2

    case (.failure(let ce1, let iter1, let sh1, _, _), .failure(let ce2, let iter2, let sh2, _, _)):
      return ce1 == ce2 && iter1 == iter2 && sh1 == sh2

    case (.gaveUp(let disc1, let iter1), .gaveUp(let disc2, let iter2)):
      return disc1 == disc2 && iter1 == iter2

    default:
      return false
    }
  }
}

// MARK: - Common Test Generators

/// Collection of commonly used test generators
public enum TestGenerators {

  /// Generator for small positive integers
  public static let smallPositiveInt = Gen.int(in: 1...100)

  /// Generator for small arrays
  public static func smallArray<T>(_ elementGen: Gen<T>) -> Gen<[T]> {
    Gen<[T]>(
      generate: { rng, size in
        let arraySize = min(size.value, 20)
        return (0..<arraySize).map { _ in elementGen.generate(&rng, size.scaled(by: 0.8)) }
      },
      shrink: Shrink { array in
        if array.isEmpty { return [] }
        var candidates: [[T]] = []

        // Shrink by removing elements
        candidates.append(Array(array.dropFirst()))
        candidates.append(Array(array.dropLast()))
        if array.count > 2 {
          candidates.append(Array(array.prefix(array.count / 2)))
        }

        return candidates
      }
    )
  }

  /// Generator for ASCII strings
  public static let asciiString = Gen<String>(
    generate: { rng, size in
      let length = min(size.value, 50)
      return String(
        (0..<length).map { _ in
          Character(UnicodeScalar(Int.random(in: 32...126, using: &rng))!)
        }
      )
    },
    shrink: Shrink { string in
      if string.isEmpty { return [] }
      return [
        "",
        String(string.prefix(string.count / 2)),
        String(string.dropFirst()),
        String(string.dropLast()),
      ]
    }
  )

  /// Generator for non-empty strings
  public static let nonEmptyString = Gen<String>(
    generate: { rng, size in
      let length = max(1, min(size.value, 30))
      return String(
        (0..<length).map { _ in
          Character(UnicodeScalar(Int.random(in: 65...90, using: &rng))!)
        }
      )
    },
    shrink: Shrink { string in
      if string.count <= 1 { return [] }
      return [
        String(string.prefix(1)),
        String(string.prefix(string.count / 2)),
      ]
    }
  )
}
