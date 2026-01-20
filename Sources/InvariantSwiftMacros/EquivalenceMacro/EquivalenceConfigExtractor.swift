import SwiftSyntax

/// Configuration extracted from @Equivalence macro attributes.
public struct EquivalenceMacroConfig {
  public let iterations: Int
  public let tolerance: Double?

  public init(iterations: Int = 500, tolerance: Double? = nil) {
    self.iterations = iterations
    self.tolerance = tolerance
  }
}

/// Extracts configuration from @Equivalence attribute syntax.
public enum EquivalenceConfigExtractor {

  /// Extract configuration from attribute syntax.
  public static func extract(from node: AttributeSyntax) -> EquivalenceMacroConfig {
    guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
      return EquivalenceMacroConfig()
    }

    var iterations = 500
    var tolerance: Double?

    for argument in arguments {
      guard let label = argument.label?.text else { continue }

      switch label {
      case "iterations":
        if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = Int(intLiteral.literal.text)
        {
          iterations = value
        }

      case "tolerance":
        if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self),
          let value = Double(floatLiteral.literal.text)
        {
          tolerance = value
        } else if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self),
          let value = Double(intLiteral.literal.text)
        {
          tolerance = value
        }

      default:
        break
      }
    }

    return EquivalenceMacroConfig(iterations: iterations, tolerance: tolerance)
  }
}
