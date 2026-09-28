// MARK: - GhostwriterExpansionRenderer Scaffold Extension
// Bodies for scaffold conformances that await human implementation.

import SwiftSyntax

extension GhostwriterExpansionRenderer {
  /// A scaffold body that compiles immediately and fails loudly if a test
  /// runs before the human fills the generator in.
  static func scaffoldFatalError(guidance: String) -> ExprSyntax {
    let summary = guidance.replacingOccurrences(of: "\n", with: " ")
    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
          DeclReferenceExprSyntax(baseName: .identifier("fatalError"))
        ),
        leftParen: .leftParenToken(),
        arguments: LabeledExprListSyntax([
          LabeledExprSyntax(
            expression: StringLiteralExprSyntax(
              content: "Ghostwriter scaffold: implement this generator. \(summary)"
            )
          )
        ]),
        rightParen: .rightParenToken()
      )
    )
  }
}
