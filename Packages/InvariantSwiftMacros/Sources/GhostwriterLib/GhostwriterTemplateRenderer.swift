import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder

enum GhostwriterTemplateRenderer {
  struct PropertyGenerator {
    let name: String
    let expression: Template<Void>
    let todoComment: String?
  }

  static func arbitraryExtension(
    typeName: String,
    propertyGenerators: [PropertyGenerator]
  ) -> String {
    let property = computedProperty(
      name: "arbitrary",
      type: "Gen<\(typeName)>",
      getterBody: CodeBlockSyntax {
        CodeBlockItemSyntax(
          item: .expr(composeCall(typeName: typeName, propertyGenerators: propertyGenerators))
        )
      }
    )

    let extensionDecl = MacroTemplateKit.Renderer.renderExtensionDecl(
      MacroTemplateKit.ExtensionSignature<Void>(
        typeName: typeName,
        conformances: ["Arbitrary"],
        members: [
          .property(
            MacroTemplateKit.PropertySignature(
              accessLevel: .public,
              name: "arbitrary",
              type: "Gen<\(typeName)>",
              isStatic: true,
              isLet: false
            )
          )
        ]
      )
    )

    let memberBlock = MemberBlockSyntax(
      members: MemberBlockItemListSyntax([
        MemberBlockItemSyntax(decl: DeclSyntax(property))
      ])
    )

    return extensionDecl.with(\.memberBlock, memberBlock).description
  }

  private static func computedProperty(
    name: String,
    type: String,
    getterBody: CodeBlockSyntax
  ) -> VariableDeclSyntax {
    let declaration = MacroTemplateKit.Declaration<Void>.property(
      MacroTemplateKit.PropertySignature(
        accessLevel: .public,
        name: name,
        type: type,
        isStatic: true,
        isLet: false
      )
    )

    var variableDecl = MacroTemplateKit.Renderer.render(declaration).as(VariableDeclSyntax.self)!
    var binding = variableDecl.bindings.first!
    binding = binding.with(
      \.accessorBlock,
      AccessorBlockSyntax(accessors: .getter(getterBody.statements))
    )
    variableDecl = variableDecl.with(\.bindings, PatternBindingListSyntax([binding]))
    return variableDecl
  }

  private static func composeCall(
    typeName: String,
    propertyGenerators: [PropertyGenerator]
  ) -> ExprSyntax {
    let callee = MacroTemplateKit.Renderer.render(Template<Void>.property("compose", on: "Gen"))
    let constructor = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier(typeName)),
      leftParen: .leftParenToken(),
      arguments: LabeledExprListSyntax(
        propertyGenerators.map { property in
          LabeledExprSyntax(
            label: .identifier(property.name),
            colon: .colonToken(trailingTrivia: .space),
            expression: propertyExpression(for: property)
          )
        }
      ),
      rightParen: .rightParenToken()
    )
    let closure = ClosureExprSyntax(
      signature: ClosureSignatureSyntax(
        parameterClause: .simpleInput(
          ClosureShorthandParameterListSyntax([
            ClosureShorthandParameterSyntax(name: .identifier("composer"))
          ])
        ),
        inKeyword: .keyword(.in, trailingTrivia: .space)
      ),
      statements: CodeBlockItemListSyntax([
        CodeBlockItemSyntax(item: .expr(ExprSyntax(constructor)))
      ])
    )

    return ExprSyntax(
      FunctionCallExprSyntax(
        calledExpression: callee,
        leftParen: nil,
        arguments: LabeledExprListSyntax([]),
        rightParen: nil,
        trailingClosure: closure
      )
    )
  }

  private static func propertyExpression(for property: PropertyGenerator) -> ExprSyntax {
    let expression = MacroTemplateKit.Renderer.render(property.expression)
    guard let todoComment = property.todoComment else {
      return expression
    }
    return expression.with(\.leadingTrivia, [.blockComment(todoComment), .spaces(1)])
  }
}
