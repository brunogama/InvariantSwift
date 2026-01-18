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
}
