import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder

public enum GhostwriterPatternRenderer {
  public static func testFunction(
    docComment: String,
    functionName: String,
    parameters: [(name: String, type: String)],
    isThrowing: Bool = false,
    bodyStatements: [CodeBlockItemSyntax]
  ) -> String {
    let declaration = MacroTemplateKit.Declaration<Void>.function(
      MacroTemplateKit.FunctionSignature(
        attributes: [.init("PropertyTest")],
        name: functionName,
        parameters: parameters.map {
          MacroTemplateKit.ParameterSignature(name: $0.name, type: $0.type)
        },
        canThrow: isThrowing,
        body: []
      )
    )

    let function = MacroTemplateKit.Renderer.render(declaration)
      .as(FunctionDeclSyntax.self)!
      .with(\.leadingTrivia, [.docLineComment("/// \(docComment)"), .newlines(1)])
      .with(\.body, CodeBlockSyntax(statements: CodeBlockItemListSyntax(bodyStatements)))

    return function.description
  }

  public static func rawStatement(_ source: String) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: source)))
  }

  public static func ifStatement(
    condition: Template<Void>,
    then bodyStatements: [CodeBlockItemSyntax]
  ) -> CodeBlockItemSyntax {
    let conditionExpr = MacroTemplateKit.Renderer.render(condition)
    let branch = CodeBlockSyntax(statements: CodeBlockItemListSyntax(bodyStatements))
    return CodeBlockItemSyntax(
      item: .expr(
        ExprSyntax(
          IfExprSyntax(
            conditions: ConditionElementListSyntax([
              ConditionElementSyntax(condition: .expression(conditionExpr))
            ]),
            body: branch
          )
        )
      )
    )
  }

  public static func letBinding(name: String, initializer: Template<Void>) -> CodeBlockItemSyntax {
    MacroTemplateKit.Renderer.render(
      Statement<Void>.letBinding(name: name, type: nil, initializer: initializer)
    )
  }

  public static func rawLetBinding(
    name: String,
    initializer source: String
  ) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      item: .decl(DeclSyntax(stringLiteral: "let \(name) = \(source)"))
    )
  }
}
