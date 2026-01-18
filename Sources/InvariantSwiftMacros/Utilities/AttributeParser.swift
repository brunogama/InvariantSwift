import SwiftSyntax

public enum AttributeParser {

  public static func arguments(
    from attribute: AttributeSyntax
  ) -> [(label: String?, expr: ExprSyntax)] {
    guard case .argumentList(let args) = attribute.arguments else {
      return []
    }
    return args.map { (label: $0.label?.text, expr: $0.expression) }
  }

  public static func stringArg(from attribute: AttributeSyntax, label: String?) -> String? {
    for arg in arguments(from: attribute) {
      if arg.label == label,
        let stringLiteral = arg.expr.as(StringLiteralExprSyntax.self)
      {
        return stringLiteral.representedLiteralValue
      }
    }
    return nil
  }

  public static func intArg(from attribute: AttributeSyntax, label: String?) -> Int? {
    for arg in arguments(from: attribute) {
      if arg.label == label,
        let intLiteral = arg.expr.as(IntegerLiteralExprSyntax.self)
      {
        return Int(intLiteral.literal.text)
      }
    }
    return nil
  }

  public static func uintArg(from attribute: AttributeSyntax, label: String?) -> UInt64? {
    for arg in arguments(from: attribute) {
      if arg.label == label,
        let intLiteral = arg.expr.as(IntegerLiteralExprSyntax.self)
      {
        return UInt64(intLiteral.literal.text)
      }
    }
    return nil
  }

  public static func boolArg(from attribute: AttributeSyntax, label: String?) -> Bool? {
    for arg in arguments(from: attribute) {
      if arg.label == label,
        let boolLiteral = arg.expr.as(BooleanLiteralExprSyntax.self)
      {
        return boolLiteral.literal.tokenKind == .keyword(.true)
      }
    }
    return nil
  }

  public static func isNilArg(from attribute: AttributeSyntax, label: String?) -> Bool {
    for arg in arguments(from: attribute) {
      if arg.label == label, arg.expr.is(NilLiteralExprSyntax.self) {
        return true
      }
    }
    return false
  }

  public static func memberAccessArg(
    from attribute: AttributeSyntax,
    label: String?
  ) -> String? {
    for arg in arguments(from: attribute) {
      if arg.label == label,
        let memberAccess = arg.expr.as(MemberAccessExprSyntax.self)
      {
        return memberAccess.declName.baseName.text
      }
    }
    return nil
  }

  public static func floatArg(from attribute: AttributeSyntax, label: String?) -> Double? {
    for arg in arguments(from: attribute) {
      if arg.label == label,
        let floatLiteral = arg.expr.as(FloatLiteralExprSyntax.self)
      {
        return Double(floatLiteral.literal.text)
      }
    }
    return nil
  }

  public static func exprArg(from attribute: AttributeSyntax, label: String?) -> ExprSyntax? {
    for arg in arguments(from: attribute) {
      if arg.label == label {
        return arg.expr
      }
    }
    return nil
  }

  public static func firstUnlabeledStringArg(from attribute: AttributeSyntax) -> String? {
    guard case .argumentList(let args) = attribute.arguments,
      let firstArg = args.first,
      firstArg.label == nil,
      let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self)
    else {
      return nil
    }
    return stringLiteral.representedLiteralValue
  }

  public static func dictionaryArg(
    from attribute: AttributeSyntax,
    label: String?
  ) -> [String: String] {
    guard let expr = exprArg(from: attribute, label: label),
      let dictExpr = expr.as(DictionaryExprSyntax.self),
      case .elements(let elements) = dictExpr.content
    else {
      return [:]
    }

    var result: [String: String] = [:]
    for element in elements {
      if let keyExpr = element.key.as(StringLiteralExprSyntax.self),
        let valueExpr = element.value.as(StringLiteralExprSyntax.self),
        let key = keyExpr.representedLiteralValue,
        let value = valueExpr.representedLiteralValue
      {
        result[key] = value
      }
    }
    return result
  }
}
