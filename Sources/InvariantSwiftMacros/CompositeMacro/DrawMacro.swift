/// DrawMacro - Expression macro for drawing values from generators
///
/// Implements the `#draw` expression macro from ISP-0002 for composite generators.
/// Used within `@Composite` functions to draw values with automatic shrinking.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `#draw` expression macro for drawing values in composite generators.
///
/// **Usage:**
/// ```swift
/// @Composite
/// func orderedPair() -> Gen<(Int, Int)> {
///     let a = #draw(Int.self)
///     let b = #draw(Int.self, .greaterThan(a))
///     return (a, b)
/// }
/// ```
///
/// The macro is expanded by `@Composite` to the appropriate `flatMap` chain.
public struct DrawMacro: ExpressionMacro {

  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> ExprSyntax {

    // Parse the arguments to determine which overload is being used
    let arguments = node.arguments
    guard !arguments.isEmpty else {
      throw DrawMacroError.missingArguments
    }

    let argList = Array(arguments)

    // Case 1: #draw(from: generator)
    if let firstArg = argList.first,
      firstArg.label?.text == "from"
    {
      return buildDrawFromGenerator(generator: firstArg.expression)
    }

    // Case 2: #draw(Type.self) or #draw(Type.self, .constraint)
    if let firstArg = argList.first,
      firstArg.label == nil
    {
      let typeExpr = firstArg.expression

      // Check if there's a constraint
      if argList.count >= 2 {
        let constraintExpr = argList[1].expression
        return buildDrawWithConstraint(type: typeExpr, constraint: constraintExpr)
      } else {
        return buildDrawType(type: typeExpr)
      }
    }

    throw DrawMacroError.invalidArguments
  }

  // MARK: - Builders

  /// Builds: __draw_placeholder(generator)
  /// This placeholder is recognized and expanded by @Composite
  private static func buildDrawFromGenerator(generator: ExprSyntax) -> ExprSyntax {
    // When used outside @Composite, this generates a placeholder
    // that will be transformed by the CompositeMacro
    FunctionCallBuilder("__composite_draw")
      .arg("generator", generator)
      .buildExpr()
  }

  /// Builds: __draw_placeholder(Type.arbitrary)
  private static func buildDrawType(type: ExprSyntax) -> ExprSyntax {
    // Extract type name from Type.self expression
    let arbitraryExpr: ExprSyntax
    if let memberAccess = type.as(MemberAccessExprSyntax.self),
      memberAccess.declName.baseName.text == "self",
      let base = memberAccess.base
    {
      // Type.self -> Type.arbitrary
      arbitraryExpr = ExprSyntax(
        MemberAccessExprSyntax(
          base: base,
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("arbitrary"))
        )
      )
    } else {
      // Fallback: assume it's already a type expression
      arbitraryExpr = ExprSyntax(
        MemberAccessExprSyntax(
          base: type,
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("arbitrary"))
        )
      )
    }

    return FunctionCallBuilder("__composite_draw")
      .arg("generator", arbitraryExpr)
      .buildExpr()
  }

  /// Builds: __draw_placeholder(Type.arbitrary.constrained(by: constraint))
  private static func buildDrawWithConstraint(
    type: ExprSyntax,
    constraint: ExprSyntax
  ) -> ExprSyntax {
    // Extract type name and build Type.arbitrary
    let arbitraryExpr: ExprSyntax
    if let memberAccess = type.as(MemberAccessExprSyntax.self),
      memberAccess.declName.baseName.text == "self",
      let base = memberAccess.base
    {
      arbitraryExpr = ExprSyntax(
        MemberAccessExprSyntax(
          base: base,
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("arbitrary"))
        )
      )
    } else {
      arbitraryExpr = ExprSyntax(
        MemberAccessExprSyntax(
          base: type,
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("arbitrary"))
        )
      )
    }

    // Build: Type.arbitrary.constrained(by: constraint)
    let constrainedExpr = FunctionCallBuilder(
      callee: ExprSyntax(
        MemberAccessExprSyntax(
          base: arbitraryExpr,
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("constrained"))
        )
      )
    )
    .arg("by", constraint)
    .buildExpr()

    return FunctionCallBuilder("__composite_draw")
      .arg("generator", constrainedExpr)
      .buildExpr()
  }
}

// MARK: - Errors

enum DrawMacroError: Error, CustomStringConvertible {
  case missingArguments
  case invalidArguments
  case invalidType

  var description: String {
    switch self {
    case .missingArguments:
      return "#draw requires arguments: #draw(from: generator) or #draw(Type.self)"

    case .invalidArguments:
      return "#draw has invalid arguments"

    case .invalidType:
      return "#draw requires a valid type expression"
    }
  }
}
