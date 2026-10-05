import SwiftSyntax

extension GhostwriterExpansionRenderer {
  static func renderArray(_ expressions: [ExpansionExpr]) -> ExprSyntax {
    ExprSyntax(
      ArrayExprSyntax(
        elements: ArrayElementListSyntax(
          expressions.enumerated().map { index, expression in
            ArrayElementSyntax(
              expression: render(expr: expression),
              trailingComma: separator(at: index, of: expressions.count)
            )
          }
        )
      )
    )
  }

  static func renderEnumGenerator(typeName: String, cases: [String]) -> ExprSyntax {
    render(
      expr: .variable("Gen").method(
        "oneOf",
        arguments: [
          .unlabeled(
            .array(
              cases.map { name in
                .variable("Gen").method(
                  "pure",
                  arguments: [.unlabeled(.property(name, on: typeName))]
                )
              }
            )
          )
        ]
      )
    )
  }
}
