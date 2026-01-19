/// CompositeMacro - Body macro for composite generator functions
///
/// Implements the `@Composite` macro from ISP-0002 for declarative
/// dependent generator construction with automatic shrinking.

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// `@Composite` macro for declarative dependent generator construction.
///
/// Transforms a function returning `Gen<T>` that uses `#draw` calls into
/// the equivalent `flatMap` chain with proper shrinking.
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
/// **Expands to:**
/// ```swift
/// func orderedPair() -> Gen<(Int, Int)> {
///     Gen<Int>.arbitrary.flatMap { a in
///         Gen<Int>.arbitrary.constrained(by: .greaterThan(a)).map { b in
///             (a, b)
///         }
///     }
/// }
/// ```
public struct CompositeMacro: BodyMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {

    let ctx = MacroContext(context: context)

    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      ctx.error(CompositeMacroDiagnostic.mustBeFunction, at: node)
      return []
    }

    guard let body = funcDecl.body else {
      ctx.error(CompositeMacroDiagnostic.missingBody, at: node)
      return []
    }

    // Collect all draw calls in order
    let collector = DrawCallCollector()
    collector.walk(body)

    // If no draw calls, return original body
    if collector.drawCalls.isEmpty {
      return Array(body.statements)
    }

    // Build the flatMap chain
    let transformedBody = buildFlatMapChain(
      drawCalls: collector.drawCalls,
      originalBody: body,
      context: context
    )

    return [CodeBlockItemSyntax(item: .expr(transformedBody))]
  }

  // MARK: - FlatMap Chain Building

  private static func buildFlatMapChain(
    drawCalls: [DrawCallInfo],
    originalBody: CodeBlockSyntax,
    context: some MacroExpansionContext
  ) -> ExprSyntax {

    // Start with the innermost expression (the return value)
    // and work outward, wrapping each draw call in a flatMap

    // Find the return statement
    let returnExpr = findReturnExpression(in: originalBody)

    // Build from inside out
    var currentExpr = returnExpr ?? ExprSyntax(TupleExprSyntax(elements: []))

    // Process draw calls in reverse order (innermost first)
    for (index, drawCall) in drawCalls.enumerated().reversed() {
      let isLast = index == drawCalls.count - 1

      if isLast {
        // Last draw uses map (not flatMap)
        currentExpr = buildMapCall(
          generator: drawCall.generatorExpr,
          variableName: drawCall.variableName,
          body: currentExpr
        )
      } else {
        // Other draws use flatMap
        currentExpr = buildFlatMapCall(
          generator: drawCall.generatorExpr,
          variableName: drawCall.variableName,
          body: currentExpr
        )
      }
    }

    return currentExpr
  }

  private static func buildFlatMapCall(
    generator: ExprSyntax,
    variableName: String,
    body: ExprSyntax
  ) -> ExprSyntax {
    // generator.flatMap { variableName in body }
    let closure = ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax {
            ClosureShorthandParameterSyntax(name: .identifier(variableName))
          }
        )
      ),
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(body))
      }
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: generator,
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("flatMap"))
        ),
        leftParen: nil,
        arguments: [],
        rightParen: nil,
        trailingClosure: closure
      )
    )
  }

  private static func buildMapCall(
    generator: ExprSyntax,
    variableName: String,
    body: ExprSyntax
  ) -> ExprSyntax {
    // generator.map { variableName in body }
    let closure = ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax {
            ClosureShorthandParameterSyntax(name: .identifier(variableName))
          }
        )
      ),
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(body))
      }
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: generator,
          period: .periodToken(),
          declName: DeclReferenceExprSyntax(baseName: .identifier("map"))
        ),
        leftParen: nil,
        arguments: [],
        rightParen: nil,
        trailingClosure: closure
      )
    )
  }

  private static func findReturnExpression(in body: CodeBlockSyntax) -> ExprSyntax? {
    for statement in body.statements.reversed() {
      if let returnStmt = statement.item.as(ReturnStmtSyntax.self) {
        return returnStmt.expression
      }
      // Check for implicit return (last expression)
      if let expr = statement.item.as(ExprSyntax.self) {
        return expr
      }
    }
    return nil
  }
}

// MARK: - Draw Call Collection

/// Information about a single #draw call
struct DrawCallInfo {
  let variableName: String
  let generatorExpr: ExprSyntax
  let location: AbsolutePosition
}

/// Syntax walker that collects #draw calls
final class DrawCallCollector: SyntaxVisitor {
  var drawCalls: [DrawCallInfo] = []

  init() {
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    // Look for: let x = #draw(...)
    for binding in node.bindings {
      guard let initializer = binding.initializer else { continue }
      guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

      let variableName = pattern.identifier.text

      // Check if initializer is a __composite_draw call (from #draw expansion)
      if let funcCall = initializer.value.as(FunctionCallExprSyntax.self),
        let declRef = funcCall.calledExpression.as(DeclReferenceExprSyntax.self),
        declRef.baseName.text == "__composite_draw"
      {
        // Extract the generator argument
        if let generatorArg = funcCall.arguments.first(where: { $0.label?.text == "generator" }) {
          drawCalls.append(
            DrawCallInfo(
              variableName: variableName,
              generatorExpr: generatorArg.expression,
              location: node.position
            )
          )
        }
      }

      // Also check for direct macro expansion (when processing before expansion)
      if let macroExpr = initializer.value.as(MacroExpansionExprSyntax.self),
        macroExpr.macroName.text == "draw"
      {
        // We'll handle this case when the macro is expanded
        // For now, record a placeholder
        let args = macroExpr.arguments
        if let firstArg = args.first {
          drawCalls.append(
            DrawCallInfo(
              variableName: variableName,
              generatorExpr: firstArg.expression,
              location: node.position
            )
          )
        }
      }
    }

    return .visitChildren
  }
}

// MARK: - Diagnostics

public enum CompositeMacroDiagnostic: String, MacroDiagnostic {
  public static let domain = "InvariantSwift.CompositeMacro"

  case mustBeFunction = "must_be_function"
  case missingBody = "missing_body"
  case invalidReturnType = "invalid_return_type"
  case noDrawCalls = "no_draw_calls"

  public var severity: DiagnosticSeverity { .error }

  public var message: String {
    switch self {
    case .mustBeFunction:
      return "@Composite can only be applied to functions"

    case .missingBody:
      return "@Composite requires a function body"

    case .invalidReturnType:
      return "@Composite function must return Gen<T>"

    case .noDrawCalls:
      return "@Composite function must contain #draw calls"
    }
  }
}

// Legacy error type for backward compatibility
enum CompositeMacroError: Error, CustomStringConvertible {
  case notAFunction
  case missingBody
  case invalidReturnType
  case noDrawCalls

  var description: String {
    switch self {
    case .notAFunction:
      return "@Composite can only be applied to functions"

    case .missingBody:
      return "@Composite requires a function body"

    case .invalidReturnType:
      return "@Composite function must return Gen<T>"

    case .noDrawCalls:
      return "@Composite function must contain #draw calls"
    }
  }
}
