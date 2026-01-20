import Foundation
import Testing
import InvariantCore
// MARK: - Diff-Based Test Assertions

/// Assert that two values have no difference.
///
/// Similar to `#expect(a == b)`, but provides detailed diff output on failure,
/// making it easier to identify exactly what changed between the values.
///
/// - Parameters:
///   - expression1: First value to compare
///   - expression2: Second value to compare
///   - message: Optional failure message prefix
///   - format: Diff format to use (default: `.default`)
public func expectNoDifference<T: Equatable>(
  _ expression1: @autoclosure () throws -> T,
  _ expression2: @autoclosure () throws -> T,
  _ message: @autoclosure () -> String? = nil,
  format: DiffFormat = .default
) {
  do {
    let lhs = try expression1()
    let rhs = try expression2()
    let messageText = message()

    guard lhs != rhs else { return }

    let printer = PrettyPrinter(config: .testOutput)

    // swiftlint:disable:next no_print
    let lhsStr = (lhs as? PrettyPrintable).map { printer.print($0) } ?? "\(lhs)"
    // swiftlint:disable:next no_print
    let rhsStr = (rhs as? PrettyPrintable).map { printer.print($0) } ?? "\(rhs)"
    let diffOutput = """
      \(format.first) \(lhsStr)
      \(format.second) \(rhsStr)
      """

    Issue.record(
      Comment(
        stringLiteral: """
          \(messageText.map { "\($0) - " } ?? "")Difference detected:

          \(diffOutput)

          (First: \(format.first), Second: \(format.second))
          """
      )
    )
  } catch {
    Issue.record(Comment(stringLiteral: "expectNoDifference threw: \(error)"))
  }
}

/// Assert that a value changes in expected ways after an operation.
///
/// Evaluates an expression before and after an operation, then compares the result
/// against expected changes. Useful for testing state mutations.
///
/// **Example:**
/// ```swift
/// var counter = Counter(count: 0)
/// expectDifference(counter) {
///   counter.increment()
/// } changes: {
///   $0.count = 1
/// }
/// ```
///
/// **Non-exhaustive mode:** Omit the `operation` to assert only specific fields changed:
/// ```swift
/// counter.increment()
/// expectDifference(counter) {
///   $0.count = 1
/// }
/// ```
///
/// - Parameters:
///   - expression: Value to track before and after operation
///   - message: Optional failure message prefix
///   - format: Diff format to use (default: `.default`)
///   - operation: Operation that mutates state (optional for non-exhaustive mode)
///   - updateExpectingResult: Closure that modifies a copy to match expected state
public func expectDifference<T: Equatable>(
  _ expression: @autoclosure () throws -> T,
  _ message: @autoclosure () -> String? = nil,
  format: DiffFormat = .default,
  operation: () throws -> Void = {},
  changes updateExpectingResult: (inout T) throws -> Void
) {
  do {
    var expected = try expression()
    try updateExpectingResult(&expected)
    try operation()
    let actual = try expression()
    let messageText = message()

    guard expected != actual else { return }

    let printer = PrettyPrinter(config: .testOutput)

    // swiftlint:disable:next no_print
    let expectedStr = (expected as? PrettyPrintable).map { printer.print($0) } ?? "\(expected)"
    // swiftlint:disable:next no_print
    let actualStr = (actual as? PrettyPrintable).map { printer.print($0) } ?? "\(actual)"
    let diffOutput = """
      \(format.first) \(expectedStr)
      \(format.second) \(actualStr)
      """

    Issue.record(
      Comment(
        stringLiteral: """
          \(messageText.map { "\($0) - " } ?? "")Difference from expected:

          \(diffOutput)

          (Expected: \(format.first), Actual: \(format.second))
          """
      )
    )
  } catch {
    Issue.record(Comment(stringLiteral: "expectDifference threw: \(error)"))
  }
}

/// Async version of `expectDifference` for testing async operations.
///
/// - Parameters:
///   - expression: Value to track before and after operation
///   - message: Optional failure message prefix
///   - format: Diff format to use (default: `.default`)
///   - operation: Async operation that mutates state
///   - updateExpectingResult: Closure that modifies a copy to match expected state
public func expectDifference<T: Equatable & Sendable>(
  _ expression: @autoclosure @Sendable () throws -> T,
  _ message: @autoclosure @Sendable () -> String? = nil,
  format: DiffFormat = .default,
  operation: @Sendable () async throws -> Void = {},
  changes updateExpectingResult: @Sendable (inout T) throws -> Void
) async {
  do {
    var expected = try expression()
    try updateExpectingResult(&expected)
    try await operation()
    let actual = try expression()
    let messageText = message()

    guard expected != actual else { return }

    let printer = PrettyPrinter(config: .testOutput)

    // swiftlint:disable:next no_print
    let expectedStr = (expected as? PrettyPrintable).map { printer.print($0) } ?? "\(expected)"
    // swiftlint:disable:next no_print
    let actualStr = (actual as? PrettyPrintable).map { printer.print($0) } ?? "\(actual)"
    let diffOutput = """
      \(format.first) \(expectedStr)
      \(format.second) \(actualStr)
      """

    Issue.record(
      Comment(
        stringLiteral: """
          \(messageText.map { "\($0) - " } ?? "")Difference from expected:

          \(diffOutput)

          (Expected: \(format.first), Actual: \(format.second))
          """
      )
    )
  } catch {
    Issue.record(Comment(stringLiteral: "expectDifference threw: \(error)"))
  }
}
