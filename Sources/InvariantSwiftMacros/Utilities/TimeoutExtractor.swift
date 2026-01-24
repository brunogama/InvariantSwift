import SwiftSyntax
import SwiftSyntaxBuilder

/// Configuration extracted from @Timeout attribute.
public struct TimeoutConfig: Sendable, Equatable {
  /// Timeout duration in seconds, or nil if timeout is disabled (.none).
  public let seconds: Double?

  public init(seconds: Double?) {
    self.seconds = seconds
  }

  /// Disabled timeout (equivalent to .none).
  public static let none = TimeoutConfig(seconds: nil)
}

/// Extracts timeout configuration from function attributes.
public enum TimeoutExtractor {

  /// Extract timeout config from a function declaration's attributes.
  ///
  /// Looks for @Timeout attribute and parses its arguments:
  /// - `@Timeout(seconds: 5.0)` → TimeoutConfig(seconds: 5.0)
  /// - `@Timeout(.seconds(10.0))` → TimeoutConfig(seconds: 10.0)
  /// - `@Timeout(.milliseconds(500))` → TimeoutConfig(seconds: 0.5)
  /// - `@Timeout(.none)` → TimeoutConfig.none
  ///
  /// Returns `nil` if no @Timeout attribute is present.
  public static func extractConfig(from funcDecl: FunctionDeclSyntax) -> TimeoutConfig? {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self) else { continue }

      let attrName = attrSyntax.attributeName.description.trimmingCharacters(
        in: .whitespacesAndNewlines
      )

      guard attrName == "Timeout" else { continue }

      // Parse timeout arguments
      guard let args = attrSyntax.arguments else {
        // No arguments - invalid, but return nil to avoid crash
        return nil
      }

      // Handle different argument formats
      switch args {
      case .argumentList(let labeledList):
        // @Timeout(seconds: 5.0)
        for labeled in labeledList {
          if labeled.label?.text == "seconds" {
            if let literal = labeled.expression.as(FloatLiteralExprSyntax.self) {
              if let seconds = Double(literal.literal.text) {
                return TimeoutConfig(seconds: seconds)
              }
            } else if let intLiteral = labeled.expression.as(IntegerLiteralExprSyntax.self) {
              if let seconds = Double(intLiteral.literal.text) {
                return TimeoutConfig(seconds: seconds)
              }
            }
          }
        }

        // @Timeout(.seconds(10.0)) or @Timeout(.milliseconds(500)) or @Timeout(.none)
        if let firstArg = labeledList.first,
          firstArg.label == nil,
          let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self)
        {
          let memberName = memberAccess.declName.baseName.text

          if memberName == "none" {
            return TimeoutConfig.none
          } else if memberName == "seconds",
            let funcCall = firstArg.expression.as(FunctionCallExprSyntax.self),
            let firstCallArg = funcCall.arguments.first
          {
            if let literal = firstCallArg.expression.as(FloatLiteralExprSyntax.self) {
              if let seconds = Double(literal.literal.text) {
                return TimeoutConfig(seconds: seconds)
              }
            } else if let intLiteral = firstCallArg.expression.as(IntegerLiteralExprSyntax.self) {
              if let seconds = Double(intLiteral.literal.text) {
                return TimeoutConfig(seconds: seconds)
              }
            }
          } else if memberName == "milliseconds",
            let funcCall = firstArg.expression.as(FunctionCallExprSyntax.self),
            let firstCallArg = funcCall.arguments.first
          {
            if let literal = firstCallArg.expression.as(IntegerLiteralExprSyntax.self) {
              if let ms = Int(literal.literal.text) {
                return TimeoutConfig(seconds: Double(ms) / 1000.0)
              }
            }
          }
        }

      default:
        break
      }
    }

    return nil
  }
}
