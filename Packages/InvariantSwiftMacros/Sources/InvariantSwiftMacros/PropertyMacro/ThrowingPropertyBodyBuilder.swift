import SwiftSyntax
import SwiftSyntaxBuilder

/// Adapts throwing property bodies to the synchronous property predicate.
enum ThrowingPropertyBodyBuilder {
  static func build(
    from body: CodeBlockSyntax,
    signature: FunctionSignatureSyntax
  ) -> CodeBlockSyntax {
    guard signature.effectSpecifiers?.throwsClause != nil else { return body }

    return CodeBlockSyntax {
      DoStmtSyntax(
        body: CodeBlockSyntax {
          TryExprSyntax(
            expression: FunctionCallExprSyntax(
              calledExpression: ClosureExprSyntax(
                signature: ClosureSignatureSyntax(
                  parameterClause: .parameterClause(ClosureParameterClauseSyntax(parameters: [])),
                  effectSpecifiers: TypeEffectSpecifiersSyntax(
                    throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
                  ),
                  returnClause: ReturnClauseSyntax(
                    type: IdentifierTypeSyntax(name: .identifier("Void"))
                  )
                ),
                statements: body.statements
              ),
              leftParen: .leftParenToken(),
              arguments: [],
              rightParen: .rightParenToken()
            )
          )
        },
        catchClauses: CatchClauseListSyntax {
          CatchClauseSyntax(
            body: CodeBlockSyntax {
              FunctionCallBuilder(type: "Issue", member: "record")
                .arg(ref: "error")
                .build()
              ReturnStmtSyntax(expression: BooleanLiteralExprSyntax(booleanLiteral: false))
            }
          )
        }
      )
    }
  }
}
