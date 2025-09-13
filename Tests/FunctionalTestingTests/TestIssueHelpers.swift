/// TestIssueHelpers.swift - Consolidated Issue Recording Utilities
///
/// Provides centralized, consistent issue reporting for property-based tests.
/// Consolidates the 270+ Issue.record calls across the test suite into
/// reusable helper functions with better consistency and maintainability.

import Testing

// MARK: - Test Issue Recording Helpers

/// Consolidated test failure reporting utilities
/// Provides consistent messaging and reduces code duplication in test files
public enum TestIssue {

  // MARK: - Property Test Failures

  /// Records property validation failure with contextual information
  public static func propertyValidationFailed(_ testName: String, details: String? = nil) {
    let message = details.map { "\(testName) failed: \($0)" } ?? "\(testName) failed"
    Issue.record(message)
  }

  /// Records basic property test failure
  public static func basicPropertyFailed() {
    Issue.record("Basic property validation failed")
  }

  /// Records async property runner failure
  public static func asyncPropertyFailed() {
    Issue.record("Async property runner validation failed")
  }

  // MARK: - Collection Test Failures

  /// Records collection-related test failure
  public static func collectionTestFailed(_ collectionType: String, size: String? = nil) {
    let sizeInfo = size.map { " (\($0))" } ?? ""
    Issue.record("\(collectionType) collection\(sizeInfo) validation failed")
  }

  /// Records empty collection test failure
  public static func emptyCollectionFailed() {
    collectionTestFailed("Empty")
  }

  /// Records large collection test failure
  public static func largeCollectionFailed() {
    collectionTestFailed("Large")
  }

  // MARK: - Type-Specific Test Failures

  /// Records type-specific integration test failure
  public static func integrationTestFailed(for type: String, index: Int? = nil) {
    let indexInfo = index.map { " \($0)" } ?? ""
    Issue.record("\(type) integration test\(indexInfo) failed")
  }

  /// Records string edge case test failure
  public static func stringEdgeCaseFailed() {
    Issue.record("String edge case validation failed")
  }

  // MARK: - Performance Test Failures

  /// Records performance test failure with iteration count
  public static func performanceTestFailed(iterations: Int) {
    Issue.record("Performance test should succeed for \(iterations) iterations")
  }

  /// Records memory validation test failure
  public static func memoryValidationFailed() {
    Issue.record("Memory validation test should succeed")
  }

  // MARK: - Concurrent Test Failures

  /// Records concurrent test failure with index
  public static func concurrentTestFailed(index: Int) {
    Issue.record("Concurrent integration test \(index) failed")
  }

  /// Records configuration integration test failure
  public static func configurationTestFailed(index: Int) {
    Issue.record("Configuration integration test \(index) failed")
  }

  // MARK: - Generator Test Failures

  /// Records generator composition test failure
  public static func generatorCompositionFailed() {
    Issue.record("Generator composition should succeed")
  }

  /// Records core generator test failure
  public static func corePropertyTestingFailed() {
    Issue.record("Core property testing should work")
  }

  // MARK: - Property Result Failures

  /// Records property result mismatch
  public static func propertyResultMismatch(_ expected: String, actual: String) {
    Issue.record("Expected \(expected), but got \(actual)")
  }

  /// Records that a property should have failed but succeeded
  public static func unexpectedPropertySuccess(_ description: String) {
    Issue.record("\(description) should not succeed")
  }

  /// Records that a property failed incorrectly
  public static func incorrectPropertyFailure(_ description: String) {
    Issue.record("\(description) should fail, not give up")
  }

  // MARK: - Generic Test Helpers

  /// Records a generic test failure with custom message
  public static func testFailed(_ message: String) {
    Issue.record(message)
  }

  /// Records a test failure with formatted string
  public static func testFailedf(_ format: String, _ args: CVarArg...) {
    let message = String(format: format, arguments: args)
    Issue.record(message)
  }

  /// Records assertion failure with context
  public static func assertionFailed<T>(
    _ condition: String,
    expected: T,
    actual: T,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    Issue.record(
      "Assertion failed: \(condition). Expected \(expected), got \(actual)",
      sourceLocation: SourceLocation(fileID: file, line: line)
    )
  }
}

// MARK: - Conditional Issue Recording

extension TestIssue {
  /// Records issue only if condition is false
  public static func recordIfFalse(_ condition: Bool, _ message: String) {
    if !condition {
      Issue.record(message)
    }
  }

  /// Records issue only if result is nil
  public static func recordIfNil<T>(_ value: T?, _ message: String) {
    if value == nil {
      Issue.record(message)
    }
  }

  /// Records issue if values don't match
  public static func recordIfNotEqual<T: Equatable>(
    _ lhs: T,
    _ rhs: T,
    _ message: String
  ) {
    if lhs != rhs {
      Issue.record(message)
    }
  }
}

// MARK: - Test Context Helpers

extension TestIssue {
  /// Creates detailed context for property test failures
  public static func propertyTestContext(
    property: String,
    iteration: Int,
    seed: UInt64,
    input: String
  ) -> String {
    """
    Property: \(property)
    Iteration: \(iteration)
    Seed: \(seed)
    Input: \(input)
    """
  }

  /// Records property failure with full context
  public static func recordPropertyFailure(
    property: String,
    iteration: Int,
    seed: UInt64,
    input: String,
    error: String
  ) {
    let context = propertyTestContext(
      property: property,
      iteration: iteration,
      seed: seed,
      input: input
    )
    Issue.record("\(error)\n\nContext:\n\(context)")
  }
}
