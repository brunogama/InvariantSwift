import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `#target` freestanding expression macro for targeted property testing.
///
/// This macro records a metric value during test execution that guides
/// the property test framework toward interesting inputs.
///
/// Usage:
/// ```swift
/// #target(array.count, label: "size")
/// #target(graph.complexity)
/// #target(matrix.conditionNumber, toward: 1.0)
/// ```
public struct TargetMacro: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {
    // Extract the value expression (first argument)
    guard let firstArg = node.arguments.first else {
      throw MacroError("Expected at least one argument")
    }
    let valueExpr = firstArg.expression

    // Check for optional label argument
    var labelExpr: ExprSyntax = "nil"
    var towardExpr: ExprSyntax?

    for argument in node.arguments.dropFirst() {
      if let label = argument.label?.text {
        switch label {
        case "label":
          labelExpr = argument.expression

        case "toward":
          towardExpr = argument.expression

        default:
          break
        }
      }
    }

    // Generate the appropriate recordTarget call
    if let toward = towardExpr {
      return """
        InvariantSwift.recordTarget(\(valueExpr), toward: \(toward), label: \(labelExpr))
        """
    } else {
      return """
        InvariantSwift.recordTarget(\(valueExpr), label: \(labelExpr))
        """
    }
  }
}

/// Simple error type for macro diagnostics
private struct MacroError: Error, CustomStringConvertible {
  let message: String
  var description: String { message }

  init(_ message: String) {
    self.message = message
  }
}
