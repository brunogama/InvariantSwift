import SwiftSyntax

extension GhostwriterExpansionRenderer {
  static func renderArray(_ expressions: [ExpansionExpr]) -> ExprSyntax {
    ExprSyntax(
      ArrayExprSyntax(
        elements: ArrayElementListSyntax(
          expressions.map { expression in
            ArrayElementSyntax(
              expression: render(expr: expression),
              trailingComma: .commaToken()
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
