import SwiftSyntax

struct StateMachineAnalysis {
  let stateFields: [StateField]
  let commandMethods: [CommandMethod]
}

struct StateField {
  let name: String
  let type: TypeSyntax
  let defaultValue: ExprSyntax?

  var hasDefaultValue: Bool { defaultValue != nil }
}

struct CommandMethod {
  let name: String
  let parameters: [CommandParameter]
  let body: CodeBlockSyntax
  let preconditionExpr: ExprSyntax?
}

struct CommandParameter {
  let name: String
  let type: TypeSyntax
}

enum StateMachineAnalyzer {

  static func analyze(_ structDecl: StructDeclSyntax) -> StateMachineAnalysis {
    let stateFields = extractStateFields(from: structDecl)
    let commandMethods = extractCommandMethods(from: structDecl)

    return StateMachineAnalysis(
      stateFields: stateFields,
      commandMethods: commandMethods
    )
  }

  private static func extractStateFields(from structDecl: StructDeclSyntax) -> [StateField] {
    var fields: [StateField] = []

    for member in structDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self),
        varDecl.bindingSpecifier.tokenKind == .keyword(.var)
      else {
        continue
      }

      for binding in varDecl.bindings {
        guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
          let typeAnnotation = binding.typeAnnotation
        else {
          continue
        }

        let field = StateField(
          name: identifier.identifier.text,
          type: typeAnnotation.type,
          defaultValue: binding.initializer?.value
        )
        fields.append(field)
      }
    }

    return fields
  }

  private static func extractCommandMethods(from structDecl: StructDeclSyntax) -> [CommandMethod] {
    var methods: [CommandMethod] = []

    for member in structDecl.memberBlock.members {
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self),
        hasCommandAttribute(funcDecl)
      else {
        continue
      }

      let parameters = funcDecl.signature.parameterClause.parameters.map { param in
        CommandParameter(
          name: (param.secondName ?? param.firstName).text,
          type: param.type
        )
      }

      let precondition = extractPrecondition(from: funcDecl)

      if let body = funcDecl.body {
        let method = CommandMethod(
          name: funcDecl.name.text,
          parameters: parameters,
          body: body,
          preconditionExpr: precondition
        )
        methods.append(method)
      }
    }

    return methods
  }

  private static func hasCommandAttribute(_ funcDecl: FunctionDeclSyntax) -> Bool {
    for attribute in funcDecl.attributes {
      if let attr = attribute.as(AttributeSyntax.self),
        let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Command"
      {
        return true
      }
    }
    return false
  }

  private static func extractPrecondition(from funcDecl: FunctionDeclSyntax) -> ExprSyntax? {
    for attribute in funcDecl.attributes {
      if let attr = attribute.as(AttributeSyntax.self),
        let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
        identifier.name.text == "Command",
        case .argumentList(let args) = attr.arguments,
        let firstArg = args.first,
        firstArg.label?.text == "precondition"
      {
        return firstArg.expression
      }
    }
    return nil
  }
}
