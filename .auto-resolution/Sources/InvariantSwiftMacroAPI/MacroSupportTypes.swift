/// MacroSupportTypes - Types needed by macro declarations
///
/// These types are duplicated here to break circular dependencies.
/// The macro API module cannot depend on InvariantSwift (which would create
/// a cycle since InvariantSwiftTesting depends on MacroAPI).

import Foundation

// MARK: - Error Behavior (mirrors DifferentialTesting.ErrorBehavior)

/// How to handle error cases in differential testing.
public enum ErrorBehavior: Sendable {
  /// Both implementations must throw the same error type
  case mustMatch

  /// Both must either succeed or throw (error types don't need to match)
  case bothThrowOrBothSucceed

  /// Candidate may succeed where reference throws (lenient migration)
  case candidateMaySucceedMore

  /// Ignore throwing behavior entirely
  case ignoreErrors
}

// MARK: - Contract Protocol (mirrors ContractTesting.ContractProtocol)

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
