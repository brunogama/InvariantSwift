import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder

public enum MacroTemplateAdapter {
  public typealias MTKAccessLevel = MacroTemplateKit.AccessLevel

  public static func makeFunction(
    accessLevel: MTKAccessLevel = .internal,
    attributes: [AttributeSignature] = [],
    isStatic: Bool = false,
    name: String,
    parameters: [FunctionParameterSyntax] = [],
    isAsync: Bool = false,
    canThrow: Bool = false,
    body: CodeBlockSyntax
  ) -> FunctionDeclSyntax {
    let declaration = MacroTemplateKit.Declaration<Void>.function(
      MacroTemplateKit.FunctionSignature(
        accessLevel: accessLevel,
        attributes: attributes,
        isStatic: isStatic,
        name: name,
        isAsync: isAsync,
        canThrow: canThrow,
        body: []
      )
    )

    var functionDecl = MacroTemplateKit.Renderer.render(declaration)
      .as(FunctionDeclSyntax.self)!

    if !parameters.isEmpty {
      let signature = functionDecl.signature.with(
        \.parameterClause,
        FunctionParameterClauseSyntax(
          parameters: FunctionParameterListSyntax(parameters)
        )
      )
      functionDecl = functionDecl.with(\.signature, signature)
    }

    return functionDecl.with(\.body, body)
  }

  public static func makeEnum(
    accessLevel: MTKAccessLevel = .internal,
    name: String,
    members: [DeclSyntax]
  ) -> EnumDeclSyntax {
    let declaration = MacroTemplateKit.Declaration<Void>.enumDecl(
      MacroTemplateKit.EnumSignature(accessLevel: accessLevel, name: name)
    )

    let memberBlock = MemberBlockSyntax(
      members: MemberBlockItemListSyntax(
        members.map { member in
          MemberBlockItemSyntax(decl: member)
        }
      )
    )

    return MacroTemplateKit.Renderer.render(declaration)
      .as(EnumDeclSyntax.self)!
      .with(\.memberBlock, memberBlock)
  }

  public static func makeExtension(
    typeName: String,
    conformances: [String]
  ) -> ExtensionDeclSyntax {
    MacroTemplateKit.Renderer.renderExtensionDecl(
      MacroTemplateKit.ExtensionSignature<Void>(typeName: typeName, conformances: conformances)
    )
  }

  public static func makeStoredProperty(
    accessLevel: MTKAccessLevel = .internal,
    attributes: [AttributeSignature] = [],
    name: String,
    type: String?,
    isStatic: Bool = false,
    isLet: Bool,
    initializer: ExprSyntax
  ) -> VariableDeclSyntax {
    let declaration = MacroTemplateKit.Declaration<Void>.property(
      MacroTemplateKit.PropertySignature(
        accessLevel: accessLevel,
        attributes: attributes,
        name: name,
        type: type,
        isStatic: isStatic,
        isLet: isLet
      )
    )

    var variableDecl = MacroTemplateKit.Renderer.render(declaration).as(VariableDeclSyntax.self)!
    var binding = variableDecl.bindings.first!
    binding = binding.with(\.initializer, InitializerClauseSyntax(value: initializer))
    variableDecl = variableDecl.with(\.bindings, PatternBindingListSyntax([binding]))
    return variableDecl
  }

  public static func makeComputedProperty(
    accessLevel: MTKAccessLevel = .internal,
    attributes: [AttributeSignature] = [],
    name: String,
    type: String,
    isStatic: Bool = false,
    getterBody: CodeBlockSyntax
  ) -> VariableDeclSyntax {
    let declaration = MacroTemplateKit.Declaration<Void>.property(
      MacroTemplateKit.PropertySignature(
        accessLevel: accessLevel,
        attributes: attributes,
        name: name,
        type: type,
        isStatic: isStatic,
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
}
