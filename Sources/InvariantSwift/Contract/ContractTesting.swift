/// ContractTesting - Core types for contract-based testing
///
/// Part of ISP-0006: Contract Testing

import Foundation

// MARK: - Contract Configuration

/// Global configuration for contract testing.
public enum ContractConfig {
  /// Whether to check contracts at runtime (debug builds only)
  nonisolated(unsafe) public static var runtimeChecks: Bool = false

  /// Whether to throw on contract violations vs assert
  nonisolated(unsafe) public static var throwOnViolation: Bool = false

  /// Enable verbose logging of contract checks
  nonisolated(unsafe) public static var verbose: Bool = false
}

// MARK: - Contract Protocol

/// Marker protocol for types that have behavioral contracts.
///
/// Types conforming to this protocol have pre/postconditions and invariants
/// that can be verified through property-based testing.
public protocol ContractProtocol {
  /// Verify all invariants hold for the current state.
  func verifyInvariants() -> Bool
}

extension ContractProtocol {
  /// Default implementation returns true (no invariants defined)
  public func verifyInvariants() -> Bool { true }
}

// MARK: - Contract Violation

/// Error thrown when a contract is violated.
public struct ContractViolation: Error, CustomStringConvertible, Sendable {
  /// Type of contract that was violated
  public enum ViolationType: String, Sendable {
    case precondition
    case postcondition
    case invariant
  }

  public let type: ViolationType
  public let message: String
  public let function: String
  public let file: String
  public let line: Int

  public init(
    type: ViolationType,
    message: String,
    function: String = #function,
    file: String = #file,
    line: Int = #line
  ) {
    self.type = type
    self.message = message
    self.function = function
    self.file = file
    self.line = line
  }

  public var description: String {
    "Contract \(type.rawValue) failed: \(message) in \(function) at \(file):\(line)"
  }
}

// MARK: - Old Value Capture

/// Captures a value before method execution for use in postconditions.
///
/// In postconditions, use `old(expression)` to refer to the value of the
/// expression as it was before the method executed.
///
/// **Example:**
/// ```swift
/// @Postcondition { $0.count == old($0.count) + 1 }
/// mutating func push(_ element: Element)
/// ```
///
/// - Parameter value: The expression to capture (evaluated once, before execution)
/// - Returns: The captured value
@inlinable
public func old<T>(_ value: @autoclosure () -> T) -> T {
  value()
}

// MARK: - Contract Checking Helpers

/// Check a precondition at runtime.
///
/// - Parameters:
///   - condition: The condition that must be true
///   - message: Description of the precondition
@inlinable
public func checkPrecondition(
  _ condition: @autoclosure () -> Bool,
  _ message: @autoclosure () -> String = "Precondition failed",
  function: String = #function,
  file: String = #file,
  line: Int = #line
) {
  guard ContractConfig.runtimeChecks else { return }

  if !condition() {
    let violation = ContractViolation(
      type: .precondition,
      message: message(),
      function: function,
      file: file,
      line: line
    )

    if ContractConfig.throwOnViolation {
      // Note: Would need to be in a throwing context
      if ContractConfig.verbose {
        print("⚠️ \(violation)")
      }
    } else {
      assertionFailure(violation.description)
    }
  }
}

/// Check a postcondition at runtime.
@inlinable
public func checkPostcondition(
  _ condition: @autoclosure () -> Bool,
  _ message: @autoclosure () -> String = "Postcondition failed",
  function: String = #function,
  file: String = #file,
  line: Int = #line
) {
  guard ContractConfig.runtimeChecks else { return }

  if !condition() {
    let violation = ContractViolation(
      type: .postcondition,
      message: message(),
      function: function,
      file: file,
      line: line
    )

    if ContractConfig.verbose {
      print("⚠️ \(violation)")
    }
    assertionFailure(violation.description)
  }
}

/// Check an invariant at runtime.
@inlinable
public func checkInvariant(
  _ condition: @autoclosure () -> Bool,
  _ message: @autoclosure () -> String = "Invariant violated",
  function: String = #function,
  file: String = #file,
  line: Int = #line
) {
  guard ContractConfig.runtimeChecks else { return }

  if !condition() {
    let violation = ContractViolation(
      type: .invariant,
      message: message(),
      function: function,
      file: file,
      line: line
    )

    if ContractConfig.verbose {
      print("⚠️ \(violation)")
    }
    assertionFailure(violation.description)
  }
}

// MARK: - Contract Test Result

/// Result of testing a contract on a conforming type.
public struct ContractTestResult: Sendable {
  public let passed: Bool
  public let operationsExecuted: Int
  public let violationsFound: [String]

  public init(passed: Bool, operationsExecuted: Int, violationsFound: [String]) {
    self.passed = passed
    self.operationsExecuted = operationsExecuted
    self.violationsFound = violationsFound
  }

  public static var success: ContractTestResult {
    ContractTestResult(passed: true, operationsExecuted: 0, violationsFound: [])
  }
}

// MARK: - Contract Operation

/// Represents an operation that can be performed on a contracted type.
public struct ContractOperation<T>: Sendable where T: Sendable {
  public let name: String
  public let precondition: @Sendable (T) -> Bool
  public let execute: @Sendable (inout T) -> Void
  public let postconditions: [@Sendable (T, T) -> Bool]  // (old, new) -> Bool

  public init(
    name: String,
    precondition: @escaping @Sendable (T) -> Bool = { _ in true },
    execute: @escaping @Sendable (inout T) -> Void,
    postconditions: [@Sendable (T, T) -> Bool] = []
  ) {
    self.name = name
    self.precondition = precondition
    self.execute = execute
    self.postconditions = postconditions
  }
}

// MARK: - Contract Test Runner

/// Runs contract tests on a conforming type.
public struct ContractTestRunner<T: ContractProtocol & Sendable>: Sendable {
  public let operations: [ContractOperation<T>]
  public let invariants: [@Sendable (T) -> Bool]

  public init(
    operations: [ContractOperation<T>],
    invariants: [@Sendable (T) -> Bool] = []
  ) {
    self.operations = operations
    self.invariants = invariants
  }

  /// Run a sequence of random operations and verify contracts.
  public func run(
    initialState: T,
    operationCount: Int = 100,
    using rng: inout some RandomNumberGenerator
  ) -> ContractTestResult {
    guard !operations.isEmpty else {
      return .success
    }

    var state = initialState
    var violations: [String] = []

    for step in 0..<operationCount {
      // Check invariants before operation
      for (idx, invariant) in invariants.enumerated() {
        if !invariant(state) {
          violations.append("Invariant \(idx) failed before step \(step)")
        }
      }

      // Pick a random valid operation
      let validOps = operations.filter { $0.precondition(state) }
      guard !validOps.isEmpty else {
        // No valid operations available
        continue
      }

      let opIndex = Int.random(in: 0..<validOps.count, using: &rng)
      let operation = validOps[opIndex]

      // Capture old state
      let oldState = state

      // Execute operation
      operation.execute(&state)

      // Check postconditions
      for (idx, postcond) in operation.postconditions.enumerated() {
        if !postcond(oldState, state) {
          violations.append("\(operation.name) postcondition \(idx) failed at step \(step)")
        }
      }

      // Check invariants after operation
      for (idx, invariant) in invariants.enumerated() {
        if !invariant(state) {
          violations.append("Invariant \(idx) failed after step \(step) (\(operation.name))")
        }
      }
    }

    return ContractTestResult(
      passed: violations.isEmpty,
      operationsExecuted: operationCount,
      violationsFound: violations
    )
  }
}
