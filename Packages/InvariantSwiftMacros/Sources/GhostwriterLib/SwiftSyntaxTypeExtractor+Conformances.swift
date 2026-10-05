import SwiftSyntax

extension SwiftSyntaxTypeExtractor {
  /// Merge extension conformances into type info.
  public static func mergeConformances(
    types: [ExtractedTypeInfo],
    extensions: [String: [String]]
  ) -> [ExtractedTypeInfo] {
    types.map { type in
      let additionalConformances = extensions[type.conformanceLookupName] ?? []
      let mergedConformances = Array(Set(type.conformances + additionalConformances))

      return ExtractedTypeInfo(
        name: type.name,
        kind: type.kind,
        sourceFile: type.sourceFile,
        line: type.line,
        conformances: mergedConformances,
        hasArbitraryAttribute: type.hasArbitraryAttribute,
        properties: type.properties,
        methods: type.methods,
        genericParameters: type.genericParameters,
        accessLevel: type.accessLevel,
        enumCases: type.enumCases,
        qualifiedName: type.qualifiedName
      )
    }
  }
}

extension TypeVisitor {
  func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> AccessLevel {
    for modifier in modifiers {
      switch modifier.name.tokenKind {
      case .keyword(let keyword):
        switch keyword {
        case .private: return .private
        case .fileprivate: return .fileprivate
        case .internal: return .internal
        case .public: return .public
        case .open: return .open
        default: continue
        }

      default: continue
      }
    }
    return .internal
  }

  func extractProperties(from members: MemberBlockItemListSyntax) -> [ExtractedProperty] {
    var properties: [ExtractedProperty] = []

    for member in members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else { continue }
      if varDecl.modifiers.contains(where: {
        ["static", "class", "lazy"].contains($0.name.text)
      }) {
        continue
      }

      let accessLevel = extractAccessLevel(from: varDecl.modifiers)

      for binding in varDecl.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }

        let name = pattern.identifier.text
        let typeName: String
        let isOptional: Bool

        if let typeAnnotation = binding.typeAnnotation {
          typeName = typeAnnotation.type.trimmedDescription
          isOptional =
            typeAnnotation.type.is(OptionalTypeSyntax.self)
            || typeAnnotation.type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
        } else {
          typeName = "Unknown"
          isOptional = false
        }

        let hasDefault = binding.initializer != nil
        let isMutable =
          varDecl.bindingSpecifier.text == "var"
          && !varDecl.modifiers.contains { $0.detail != nil }
          && binding.accessorBlock == nil

        if !isMutable && hasDefault {
          continue
        }
        if binding.accessorBlock != nil && binding.initializer == nil {
          continue
        }

        properties.append(
          ExtractedProperty(
            name: name,
            typeName: typeName,
            isOptional: isOptional,
            isMutable: isMutable,
            hasDefaultValue: hasDefault,
            accessLevel: accessLevel
          )
        )
      }
    }

    return properties
  }

  func extractMethods(from members: MemberBlockItemListSyntax) -> [ExtractedMethod] {
    var methods: [ExtractedMethod] = []

    for member in members {
      if let initializer = member.decl.as(InitializerDeclSyntax.self) {
        let parameters = initializer.signature.parameterClause.parameters.map { param in
          ExtractedParameter(
            label: param.firstName.text == "_" ? nil : param.firstName.text,
            name: param.secondName?.text ?? param.firstName.text,
            typeName: param.type.trimmedDescription
          )
        }
        methods.append(
          ExtractedMethod(
            name: initializer.optionalMark == nil ? "init" : "init?",
            returnType: nil,
            parameters: parameters,
            accessLevel: extractAccessLevel(from: initializer.modifiers),
            isStatic: false,
            isMutating: false,
            isThrowing: initializer.signature.effectSpecifiers?.throwsClause != nil,
            isAsync: initializer.signature.effectSpecifiers?.asyncSpecifier != nil
          )
        )
        continue
      }
      guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else { continue }

      let parameters = funcDecl.signature.parameterClause.parameters.map { param in
        ExtractedParameter(
          label: param.firstName.text == "_" ? nil : param.firstName.text,
          name: param.secondName?.text ?? param.firstName.text,
          typeName: param.type.trimmedDescription
        )
      }
      let isStatic = funcDecl.modifiers.contains {
        $0.name.text == "static" || $0.name.text == "class"
      }

      methods.append(
        ExtractedMethod(
          name: funcDecl.name.text,
          returnType: funcDecl.signature.returnClause?.type.trimmedDescription,
          parameters: parameters,
          accessLevel: extractAccessLevel(from: funcDecl.modifiers),
          isStatic: isStatic,
          isMutating: funcDecl.modifiers.contains { $0.name.text == "mutating" },
          isThrowing: funcDecl.signature.effectSpecifiers?.throwsClause != nil,
          isAsync: funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        )
      )
    }

    return methods
  }

  func computeLineNumber(for position: AbsolutePosition) -> Int {
    position.utf8Offset / 40 + 1
  }
}
