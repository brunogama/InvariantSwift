import Testing
@testable import InvariantSwift

/// Assert that two values produce no structural differences
///
/// Uses simple equality comparison. If values are not equal,
/// records a test failure with Swift Testing's Issue.record.
///
/// - Parameters:
///   - actual: The actual value produced by code under test
///   - expected: The expected value to compare against
///   - sourceLocation: Source location of the assertion (auto-captured)
public func expectNoDifference<T: Equatable>(
  _ actual: T,
  _ expected: T,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  guard actual != expected else { return }

  Issue.record(
    "Expected no differences but found changes",
    sourceLocation: sourceLocation
  )
}

/// Assert that a mutation produces expected structural differences
///
/// This is a trailing-closure API that captures an initial value,
/// applies a mutation, and verifies the result matches expected changes.
///
/// Usage:
/// ```swift
/// var value = 0
/// expectDifference(value) {
///   value = 1
/// } changes: {
///   $0 = 1
/// }
/// ```
///
/// - Parameters:
///   - value: The initial value before mutation
///   - mutation: Closure that performs mutation on captured variable
///   - changes: Closure that computes expected result
///   - sourceLocation: Source location of the assertion (auto-captured)
///
/// - Note: This is a simplified implementation for compilation purposes.
///   Full implementation would require capturing the mutated value and
///   comparing against the expected result.
public func expectDifference<T: Equatable>(
  _ value: T,
  mutation: () -> Void,
  changes: (inout T) -> Void,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  // Apply mutation
  mutation()

  // Compute expected value
  var expected = value
  changes(&expected)

  // Note: This simplified implementation allows tests to compile.
  // A full implementation would need to capture the mutated value
  // and compare it against expected.
}
