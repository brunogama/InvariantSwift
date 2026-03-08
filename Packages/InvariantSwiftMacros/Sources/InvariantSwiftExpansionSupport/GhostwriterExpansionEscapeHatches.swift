import SwiftSyntax
import SwiftSyntaxBuilder

enum GhostwriterExpansionEscapeHatches {
  static func renderExpectation(
    condition: ExprSyntax,
    message: String
  ) -> CodeBlockItemSyntax {
    let arguments = LabeledExprListSyntax {
      LabeledExprSyntax(expression: condition)
      LabeledExprSyntax(
        expression: StringLiteralExprSyntax(content: message)
      )
    }

    return CodeBlockItemSyntax(
      item: .expr(
        ExprSyntax(
          MacroExpansionExprSyntax(
            pound: .poundToken(),
            macroName: .identifier("expect"),
            arguments: arguments
          )
        )
      )
    )
  }

  static func renderExactlyOneTrue(_ expressions: [ExprSyntax]) -> ExprSyntax {
    let source =
      "[\(expressions.map(\.description).joined(separator: ", "))].filter { $0 }.count == 1"
    return ExprSyntax(stringLiteral: source)
  }
}
