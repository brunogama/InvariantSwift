import SwiftSyntax
import SwiftSyntaxBuilder

/// Extracted shrink hint metadata from a parameter.
struct ShrinkHintMetadata {
  /// The parameter name
  let parameterName: String

  /// The literal value to shrink toward (as source code)
  let targetValue: String

  /// The type of the target value (inferred from literal)
  let targetType: String?
}

/// Extracts @ShrinkTowards attributes from function parameters.
enum ShrinkHintExtractor {

  /// Extracts shrink hints from all parameters in a function.
  ///
  /// - Parameter funcDecl: The function declaration to analyze
  /// - Returns: Array of shrink hint metadata, one per annotated parameter
  static func extractHints(from funcDecl: FunctionDeclSyntax) -> [ShrinkHintMetadata] {
    let parameters = funcDecl.signature.parameterClause.parameters

    return parameters.compactMap { param in
      extractHint(from: param)
    }
  }

  /// Extracts shrink hint from a single parameter.
  ///
  /// - Parameter param: The parameter to analyze
  /// - Returns: Shrink hint metadata if @ShrinkTowards is present, nil otherwise
  private static func extractHint(from param: FunctionParameterSyntax) -> ShrinkHintMetadata? {
    guard let attributes = param.attributes else {
      return nil
    }

    for attribute in attributes {
      guard let attr = attribute.as(AttributeSyntax.self),
        attr.attributeName.description.contains("ShrinkTowards")
      else {
        continue
      }

      // Extract target value from macro arguments
      guard let arguments = attr.arguments,
        case .argumentList(let argList) = arguments,
        let firstArg = argList.first
      else {
        continue
      }

      let targetValue = firstArg.expression.description.trimmingCharacters(in: .whitespaces)
      let targetType = inferType(from: firstArg.expression)

      let parameterName = extractParameterName(from: param)

      return ShrinkHintMetadata(
        parameterName: parameterName,
        targetValue: targetValue,
        targetType: targetType
      )
    }

    return nil
  }

  /// Extracts the parameter name from its syntax.
  ///
  /// Handles both labeled and unlabeled parameters:
  /// - `name: Int` → "name"
  /// - `_ name: Int` → "name"
  /// - `name name: Int` → "name"
  private static func extractParameterName(from param: FunctionParameterSyntax) -> String {
    // If there's a second name (internal name), use it
    if let secondName = param.secondName {
      return secondName.text
    }
    // Otherwise use the first name
    return param.firstName.text
  }

  /// Infers the Swift type from a literal expression.
  ///
  /// Supports:
  /// - Integer literals: `0`, `1`, `-10` → "Int"
  /// - String literals: `""`, `"test"` → "String"
  /// - Float literals: `0.0`, `1.5` → "Double"
  /// - Boolean literals: `true`, `false` → "Bool"
  ///
  /// - Parameter expr: The expression to analyze
  /// - Returns: Inferred type name, or nil if unknown
  private static func inferType(from expr: ExprSyntax) -> String? {
    if expr.is(IntegerLiteralExprSyntax.self) {
      return "Int"
    }
    if expr.is(StringLiteralExprSyntax.self) {
      return "String"
    }
    if expr.is(FloatLiteralExprSyntax.self) {
      return "Double"
    }
    if expr.is(BooleanLiteralExprSyntax.self) {
      return "Bool"
    }
    return nil
  }
}
