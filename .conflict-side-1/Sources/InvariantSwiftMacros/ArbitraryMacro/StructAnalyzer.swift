import SwiftSyntax
import SwiftSyntaxBuilder

struct AnalyzedField {
  let name: String
  let type: TypeSyntax
  let isOptional: Bool
  let hasDefaultValue: Bool
  let defaultValue: ExprSyntax?

  init(name: String, type: TypeSyntax, defaultValue: ExprSyntax? = nil) {
    self.name = name
    self.type = type
    self.isOptional =
      type.is(OptionalTypeSyntax.self)
      || (type.as(IdentifierTypeSyntax.self)?.name.text == "Optional")
    self.hasDefaultValue = defaultValue != nil
    self.defaultValue = defaultValue
  }
}

enum StructAnalyzer {

  static func extractFields(from structDecl: StructDeclSyntax) -> [AnalyzedField] {
    var fields: [AnalyzedField] = []

    for member in structDecl.memberBlock.members {
      guard let varDecl = member.decl.as(VariableDeclSyntax.self) else {
        continue
      }

      let isComputed = varDecl.bindings.contains { binding in
        binding.accessorBlock != nil
      }

      guard !isComputed else {
        continue
      }

      for binding in varDecl.bindings {
        guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
          let typeAnnotation = binding.typeAnnotation
        else {
          continue
        }

        let defaultValue = binding.initializer?.value

        fields.append(
          AnalyzedField(
            name: pattern.identifier.text,
            type: typeAnnotation.type,
            defaultValue: defaultValue
          )
        )
      }
    }

    return fields
  }

  /// Extracts init parameter labels from explicit initializers
  /// Returns nil if no explicit init is found (uses memberwise init)
  static func extractInitParameters(from structDecl: StructDeclSyntax) -> [String]? {
    for member in structDecl.memberBlock.members {
      guard let initDecl = member.decl.as(InitializerDeclSyntax.self) else {
        continue
      }

      // Found an explicit init, extract parameter labels
      var params: [String] = []
      for param in initDecl.signature.parameterClause.parameters {
        // Use external name if present, otherwise internal name
        let label = param.firstName.text
        if label != "_" {  // Skip unlabeled params
          params.append(label)
        }
      }
      return params
    }
    return nil  // No explicit init found
  }

  /// Checks if stored property names match init parameter labels
  /// Returns list of mismatched field names, empty if all match
  static func findInitMismatches(
    fields: [AnalyzedField],
    initParams: [String]?
  ) -> [String] {
    guard let initParams = initParams else {
      // No explicit init - memberwise init will match field names
      return []
    }

    var mismatches: [String] = []
    for field in fields {
      // swiftlint:disable:next for_where
      if !initParams.contains(field.name) {
        mismatches.append(field.name)
      }
    }
    return mismatches
  }
}
