import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Closure Builder

/// Builder for constructing closure expressions.
/// Supports single-param, multi-param, and trailing closure patterns.
public struct ClosureBuilder {
  private var parameters: [String] = []
  private var statements: [CodeBlockItemSyntax] = []

  public init() {}

  /// Add a parameter name
  public func param(_ name: String) -> Self {
    var copy = self
    copy.parameters.append(name)
    return copy
  }

  /// Add multiple parameters
  public func params(_ names: [String]) -> Self {
    var copy = self
    copy.parameters.append(contentsOf: names)
    return copy
  }

  /// Add a statement
  public func statement(_ stmt: some StmtSyntaxProtocol) -> Self {
    var copy = self
    copy.statements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax(stmt))))
    return copy
  }

  /// Add an expression as statement
  public func expr(_ expression: ExprSyntax) -> Self {
    var copy = self
    copy.statements.append(CodeBlockItemSyntax(item: .expr(expression)))
    return copy
  }

  /// Add a return expression
  public func `return`(_ expression: ExprSyntax) -> Self {
    var copy = self
    let returnStmt = ReturnStmtSyntax(expression: expression)
    copy.statements.append(CodeBlockItemSyntax(item: .stmt(StmtSyntax(returnStmt))))
    return copy
  }

  /// Build the closure
  public func build() -> ClosureExprSyntax {
    let signature: ClosureSignatureSyntax? =
      parameters.isEmpty
      ? nil
      : ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax {
            for param in parameters {
              ClosureShorthandParameterSyntax(name: .identifier(param))
            }
          }
        )
      )

    return ClosureExprSyntax(
      signature: signature,
      statements: CodeBlockItemListSyntax(statements)
    )
  }

  /// Build as ExprSyntax
  public func buildExpr() -> ExprSyntax {
    ExprSyntax(build())
  }
}

// MARK: - Map Closure Shorthand

extension ClosureBuilder {
  /// Creates a map closure: `{ a, b in Type(a: a, b: b) }`
  public static func mapToInit(
    type: String,
    fields: [(name: String, param: String)]
  ) -> ClosureBuilder {
    let params = fields.map(\.param)
    let initArgs = fields.map {
      (label: $0.name, value: ExprSyntax(SyntaxFactory.declRef($0.param)))
    }
    let initCall = FunctionCallBuilder.initCall(type: type, arguments: initArgs).buildExpr()

    return ClosureBuilder()
      .params(params)
      .return(initCall)
  }

  /// Creates a simple transform closure: `{ $0.property }`
  public static func propertyAccess(_ property: String) -> ClosureBuilder {
    let access = SyntaxFactory.memberAccess(
      base: ExprSyntax(SyntaxFactory.declRef("$0")),
      member: property
    )
    return ClosureBuilder()
      .return(ExprSyntax(access))
  }
}
