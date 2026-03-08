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
  public static let none = Self(seconds: nil)
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
    for attr in funcDecl.attributes where attr.as(AttributeSyntax.self) != nil {
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
        if let config = extractLabeledSeconds(from: labeledList) {
          return config
        }

        // @Timeout(.seconds(10.0)) or @Timeout(.milliseconds(500)) or @Timeout(.none)
        if let config = extractMemberAccessTimeout(from: labeledList) {
          return config
        }

      default:
        break
      }
    }

    return nil
  }

  /// Extract timeout from labeled argument like `@Timeout(seconds: 5.0)`.
  private static func extractLabeledSeconds(from list: LabeledExprListSyntax) -> TimeoutConfig? {
    for labeled in list where labeled.label?.text == "seconds" {
      if let literal = labeled.expression.as(FloatLiteralExprSyntax.self),
        let seconds = Double(literal.literal.text)
      {
        return TimeoutConfig(seconds: seconds)
      } else if let intLiteral = labeled.expression.as(IntegerLiteralExprSyntax.self),
        let seconds = Double(intLiteral.literal.text)
      {
        return TimeoutConfig(seconds: seconds)
      }
    }
    return nil
  }

  /// Extract timeout from member access like `@Timeout(.seconds(10.0))` or `@Timeout(.none)`.
  private static func extractMemberAccessTimeout(from list: LabeledExprListSyntax) -> TimeoutConfig?
  {
    guard let firstArg = list.first, firstArg.label == nil else {
      return nil
    }

    if let memberAccess = firstArg.expression.as(MemberAccessExprSyntax.self),
      memberAccess.declName.baseName.text == "none"
    {
      return TimeoutConfig.none
    }

    guard let funcCall = firstArg.expression.as(FunctionCallExprSyntax.self),
      let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self),
      let firstCallArg = funcCall.arguments.first
    else {
      return nil
    }

    let memberName = memberAccess.declName.baseName.text

    if memberName == "seconds" {
      return extractSecondsFromCall(firstCallArg)
    } else if memberName == "milliseconds" {
      return extractMillisecondsFromCall(firstCallArg)
    }

    return nil
  }

  /// Extract seconds from function call argument.
  private static func extractSecondsFromCall(_ arg: LabeledExprSyntax) -> TimeoutConfig? {
    if let literal = arg.expression.as(FloatLiteralExprSyntax.self),
      let seconds = Double(literal.literal.text)
    {
      return TimeoutConfig(seconds: seconds)
    } else if let intLiteral = arg.expression.as(IntegerLiteralExprSyntax.self),
      let seconds = Double(intLiteral.literal.text)
    {
      return TimeoutConfig(seconds: seconds)
    }
    return nil
  }

  /// Extract milliseconds from function call argument and convert to seconds.
  private static func extractMillisecondsFromCall(_ arg: LabeledExprSyntax) -> TimeoutConfig? {
    if let literal = arg.expression.as(IntegerLiteralExprSyntax.self),
      let ms = Int(literal.literal.text)
    {
      return TimeoutConfig(seconds: Double(ms) / 1000.0)
    }
    return nil
  }
}
