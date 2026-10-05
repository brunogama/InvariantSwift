import SwiftSyntax
import SwiftSyntaxBuilder

/// Adapts throwing property bodies to the synchronous property predicate.
enum ThrowingPropertyBodyBuilder {
  static let errorRecorderName = "invariantSwiftThrowingPropertyErrorRecorder"

  static func supportsReturnType(_ signature: FunctionSignatureSyntax) -> Bool {
    let returnType = signature.returnClause?.type.trimmedDescription
    return returnType == nil
      || ["()", "Void", "Swift.Void", "Bool", "Swift.Bool"].contains(returnType)
  }
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
          buildCatchClause()
        }
      )
    }
  }

  private static func buildCatchClause() -> CatchClauseSyntax {
    CatchClauseSyntax(
      body: CodeBlockSyntax {
        IfExprSyntax(
          conditions: ConditionElementListSyntax {
            ConditionElementSyntax(
              condition: .expression(
                ExprSyntax(
                  FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: .identifier(errorRecorderName)),
                      declName: DeclReferenceExprSyntax(baseName: .identifier("shouldRecord"))
                    ),
                    leftParen: .leftParenToken(),
                    arguments: [],
                    rightParen: .rightParenToken()
                  )
                )
              )
            )
          },
          body: CodeBlockSyntax {
            FunctionCallBuilder(type: "Issue", member: "record")
              .arg(ref: "error")
              .build()
          }
        )
        ReturnStmtSyntax(expression: BooleanLiteralExprSyntax(booleanLiteral: false))
      }
    )
  }
}
