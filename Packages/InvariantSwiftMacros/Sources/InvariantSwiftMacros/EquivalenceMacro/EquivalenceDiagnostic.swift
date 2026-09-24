import SwiftDiagnostics
import SwiftSyntax

/// Diagnostic messages for @Equivalence macro errors.
public enum EquivalenceDiagnostic: String, DiagnosticMessage {
  case mustBeFunction
  case requiresTwoFunctionParameters
  case incompatibleFunctionTypes
  case toleranceRequiresBinaryFloatingPoint
  case requiresDefaultImplementations
  case signatureMismatch
  case requiresInputParameters
  case tooManyInputParameters
  case voidOutputNotComparable
  case genericFunctionUnsupported

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

    case .requiresDefaultImplementations:
      return
        "@Equivalence requires a default value on both parameters, naming the "
        + "implementations to compare (reference: @escaping (Int) -> Int = oldSort)"

    case .signatureMismatch:
      return
        "Reference and candidate must have the same function type; the generated test "
        + "calls both the same way, using the reference's inputs and effects"

    case .requiresInputParameters:
      return "@Equivalence requires the compared functions to take at least one input"

    case .tooManyInputParameters:
      return "@Equivalence supports at most three inputs, the widest Gen.zip available"

    case .voidOutputNotComparable:
      return "@Equivalence requires a non-Void return type; two Void results always match"

    case .genericFunctionUnsupported:
      return
        "@Equivalence cannot be applied to a generic function; the generated test is a "
        + "peer and cannot see the function's type parameters"
    }
  }

  public var diagnosticID: MessageID {
    MessageID(domain: "InvariantSwiftMacros", id: rawValue)
  }

  public var severity: DiagnosticSeverity {
    .error
  }
}
