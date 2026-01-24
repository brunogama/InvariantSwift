import SwiftDiagnostics
import SwiftSyntax

/// Diagnostic messages for @Equivalence macro errors.
public enum EquivalenceDiagnostic: String, DiagnosticMessage {
  case mustBeFunction
  case requiresTwoFunctionParameters
  case incompatibleFunctionTypes
  case toleranceRequiresBinaryFloatingPoint

  public var message: String {
    switch self {
    case .mustBeFunction:
      return "@Equivalence can only be applied to functions"

    case .requiresTwoFunctionParameters:
      return "@Equivalence requires exactly two function parameters (reference, candidate)"

    case .incompatibleFunctionTypes:
      return "Reference and candidate functions must have matching signatures"

    case .toleranceRequiresBinaryFloatingPoint:
      return
        "tolerance parameter requires Output type to conform to BinaryFloatingPoint "
        + "(Double, Float, Float16, Float80, CGFloat)"
    }
  }

  public var diagnosticID: MessageID {
    MessageID(domain: "InvariantSwiftMacros", id: rawValue)
  }

  public var severity: DiagnosticSeverity {
    .error
  }
}
