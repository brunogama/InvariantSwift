import SwiftDiagnostics
import SwiftSyntax

/// Diagnostic messages for property assertion macros (@Idempotent, @Deterministic).
///
/// These diagnostics provide clear, actionable error messages when macros
/// are applied incorrectly.
public enum PropertyAssertionDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.PropertyAssertionMacro"

  case mustBeFunction = "must_be_function"
  case mustHaveParameters = "must_have_parameters"
  case returnTypeMustBeEquatable = "return_type_must_be_equatable"
  case voidReturnNotAllowed = "void_return_not_allowed"

  public var message: String {
    switch self {
    case .mustBeFunction:
      return "Property assertion macros can only be applied to functions"

    case .mustHaveParameters:
      return "Function must have at least one parameter for property testing"

    case .returnTypeMustBeEquatable:
      return "Return type must conform to Equatable to verify property"

    case .voidReturnNotAllowed:
      return "Function must return a value (Void return type not allowed)"
    }
  }

  public var severity: DiagnosticSeverity {
    .error
  }
}
