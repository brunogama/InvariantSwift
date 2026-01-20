/// RegressionExtractor - Extract @Regression configuration from attributes
///
/// Part of ISP-0004: Example Database and Reproducible Failures

import SwiftSyntax

/// Configuration extracted from @Regression attribute
public struct RegressionConfig: Sendable {
  /// Whether to replay saved examples first (default: true)
  public let replayFirst: Bool

  /// Maximum examples to replay (nil = all)
  public let maxExamples: Int?

  public static let `default` = Self(replayFirst: true, maxExamples: nil)

  public init(replayFirst: Bool = true, maxExamples: Int? = nil) {
    self.replayFirst = replayFirst
    self.maxExamples = maxExamples
  }
}

/// Helper to extract @Regression configuration from attributes
public enum RegressionExtractor {

  /// Extract configuration from a function's attributes
  public static func extractConfig(from funcDecl: FunctionDeclSyntax) -> RegressionConfig? {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "Regression"
      else { continue }

      return parseRegressionAttribute(attrSyntax)
    }
    return nil
  }

  /// Check if @Regression is present (without needing to parse config)
  public static func hasRegressionAttribute(_ funcDecl: FunctionDeclSyntax) -> Bool {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "Regression"
      else { continue }
      return true
    }
    return false
  }

  private static func parseRegressionAttribute(_ attr: AttributeSyntax) -> RegressionConfig {
    guard let args = attr.arguments?.as(LabeledExprListSyntax.self) else {
      return .default
    }

    var replayFirst: Bool = true
    var maxExamples: Int?

    for arg in args {
      let label = arg.label?.text

      switch label {
      case "replayFirst":
        if let boolLiteral = arg.expression.as(BooleanLiteralExprSyntax.self) {
          replayFirst = boolLiteral.literal.tokenKind == .keyword(.true)
        }

      case "maxExamples":
        if let intLiteral = arg.expression.as(IntegerLiteralExprSyntax.self) {
          maxExamples = Int(intLiteral.literal.text)
        }

      default:
        break
      }
    }

    return RegressionConfig(replayFirst: replayFirst, maxExamples: maxExamples)
  }
}
