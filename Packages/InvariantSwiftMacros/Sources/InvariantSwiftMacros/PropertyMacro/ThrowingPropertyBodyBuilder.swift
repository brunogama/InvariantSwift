import SwiftSyntax
import SwiftSyntaxBuilder

/// Adapts throwing property bodies to the synchronous property predicate.
enum ThrowingPropertyBodyBuilder {
  static func build(
    from body: CodeBlockSyntax,
    signature: FunctionSignatureSyntax
  ) -> CodeBlockSyntax {
    guard signature.effectSpecifiers?.throwsClause != nil else { return body }

    let returnsBool = ["Bool", "Swift.Bool"].contains(
      signature.returnClause?.type.trimmedDescription ?? ""
    )
    let invocation = TryExprSyntax(
      expression: FunctionCallExprSyntax(
        calledExpression: ClosureExprSyntax(
          signature: ClosureSignatureSyntax(
            parameterClause: .parameterClause(ClosureParameterClauseSyntax(parameters: [])),
            effectSpecifiers: TypeEffectSpecifiersSyntax(
              throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
            ),
            returnClause: ReturnClauseSyntax(
              type: IdentifierTypeSyntax(name: .identifier(returnsBool ? "Bool" : "Void"))
            )
          ),
          statements: body.statements
        ),
        leftParen: .leftParenToken(),
        arguments: [],
        rightParen: .rightParenToken()
      )
    )

    return CodeBlockSyntax {
      DoStmtSyntax(
        body: CodeBlockSyntax {
          if returnsBool {
            GuardStmtSyntax(
              conditions: [.init(condition: .expression(ExprSyntax(invocation)))],
              body: CodeBlockSyntax {
                ReturnStmtSyntax(expression: BooleanLiteralExprSyntax(booleanLiteral: false))
              }
            )
          } else {
            invocation
          }
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
