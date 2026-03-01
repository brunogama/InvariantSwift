import SwiftSyntax

// MARK: - Member Collection

extension RuleBasedTestMacro {

  static func collectRules(from structDecl: StructDeclSyntax) -> [RuleInfo] {
    var rules: [RuleInfo] = []

    for member in structDecl.memberBlock.members {
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

      let hasRule = funcDecl.attributes.contains { attr in
        if let identAttr = attr.as(AttributeSyntax.self),
          let ident = identAttr.attributeName.as(IdentifierTypeSyntax.self)
        {
          return ident.name.text == "Rule"
        }
        return false
      }

      guard hasRule else { continue }

      let precondition = extractPrecondition(from: funcDecl)
      let weight = extractWeight(from: funcDecl)

      rules.append(
        RuleInfo(
          name: funcDecl.name.text,
          weight: weight,
          preconditionExpr: precondition,
          isMutating: funcDecl.modifiers.contains { $0.name.text == "mutating" }
        )
      )
    }

    return rules
  }

  static func collectInvariants(from structDecl: StructDeclSyntax) -> [InvariantInfo] {
    var invariants: [InvariantInfo] = []

    for member in structDecl.memberBlock.members {
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

      let hasInvariant = funcDecl.attributes.contains { attr in
        if let identAttr = attr.as(AttributeSyntax.self),
          let ident = identAttr.attributeName.as(IdentifierTypeSyntax.self)
        {
          return ident.name.text == "Invariant"
        }
        return false
      }

      guard hasInvariant else { continue }

      invariants.append(InvariantInfo(name: funcDecl.name.text))
    }

    return invariants
  }

  static func collectBundles(from structDecl: StructDeclSyntax) -> [BundleInfo] {
    var bundles: [BundleInfo] = []

    for member in structDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }

      let hasBundle = varDecl.attributes.contains { attr in
        if let identAttr = attr.as(AttributeSyntax.self),
          let ident = identAttr.attributeName.as(IdentifierTypeSyntax.self)
        {
          return ident.name.text == "Bundle"
        }
        return false
      }

      guard hasBundle else { continue }

      for binding in varDecl.bindings {
        if let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
          bundles.append(BundleInfo(name: name))
        }
      }
    }

    return bundles
  }

  static func extractPrecondition(from funcDecl: FunctionDeclSyntax) -> ExprSyntax? {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "Precondition"
      else { continue }

      if let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self),
        let firstArg = args.first
      {
        return firstArg.expression
      }
    }
    return nil
  }

  static func extractWeight(from funcDecl: FunctionDeclSyntax) -> Int {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "Rule"
      else { continue }

      if let args = attrSyntax.arguments?.as(LabeledExprListSyntax.self) {
        for arg in args where arg.label?.text == "weight" {
          if let literal = arg.expression.as(IntegerLiteralExprSyntax.self) {
            return Int(literal.literal.text) ?? 1
          }
        }
      }
    }
    return 1
  }
}
