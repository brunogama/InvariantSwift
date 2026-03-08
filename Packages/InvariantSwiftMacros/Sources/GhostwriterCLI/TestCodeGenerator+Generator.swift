// MARK: - TestCodeGenerator Generator Result Analysis
// Type analysis for generator expression generation.

import Foundation
import MacroTemplateKit

extension TestCodeGenerator {
  /// Determine generator result for a property type.
  public func generatorResult(for typeName: String) -> GeneratorResult {
    switch generatorTemplateResult(for: typeName) {
    case .success(let expression):
      return .success(MacroTemplateKit.Renderer.render(expression).description)

    case .todoRequired(let typeName, let reason):
      return .todoRequired(typeName: typeName, reason: reason)
    }
  }

  func generatorTemplateResult(for typeName: String) -> GeneratorTemplateResult {
    let cleanedType = cleanTypeName(typeName)
    let isOptional = typeName.contains("?") || typeName.hasPrefix("Optional<")

    let result = analyzeType(cleanedType)

    if isOptional, case .success(let expression) = result {
      return .success(composerGenerateOptionalCall(for: expression))
    }

    return result
  }

  private func cleanTypeName(_ typeName: String) -> String {
    var cleaned =
      typeName
      .replacingOccurrences(of: "?", with: "")
      .replacingOccurrences(of: "!", with: "")
      .trimmingCharacters(in: .whitespaces)

    if cleaned.hasPrefix("Optional<") && cleaned.hasSuffix(">") {
      cleaned = String(cleaned.dropFirst(9).dropLast())
    }

    return cleaned
  }

  private func analyzeType(_ cleanedType: String) -> GeneratorTemplateResult {
    if let arrayResult = analyzeArrayType(cleanedType) {
      return arrayResult
    }

    if let setResult = analyzeSetType(cleanedType) {
      return setResult
    }

    if isDictionaryType(cleanedType) {
      return .todoRequired(
        typeName: cleanedType,
        reason: "Dictionary generation not yet supported"
      )
    }

    if Self.knownGeneratableTypes.contains(cleanedType) {
      return .success(composerGenerateCall(for: cleanedType))
    }

    return .todoRequired(
      typeName: cleanedType,
      reason: "Type does not have a known generator"
    )
  }

  private func analyzeArrayType(_ type: String) -> GeneratorTemplateResult? {
    if type.hasPrefix("Array<") && type.hasSuffix(">") {
      let inner = String(type.dropFirst(6).dropLast())
      return handleArrayElement(inner)
    }

    if type.hasPrefix("[") && type.hasSuffix("]") && !type.contains(":") {
      let inner = String(type.dropFirst().dropLast())
      return handleArrayElement(inner)
    }

    return nil
  }

  private func handleArrayElement(_ inner: String) -> GeneratorTemplateResult {
    let innerCheck = generatorTemplateResult(for: inner)

    switch innerCheck {
    case .success:
      return .success(
        Template<Void>.variable("composer")
          .method("generate") {
            TemplateArgument<Void>.labeled(
              "using",
              .variable("Gen").method("array") {
                TemplateArgument<Void>.labeled("of", .property("arbitrary", on: inner))
              }
            )
          }
      )

    case .todoRequired(let typeName, let reason):
      return .todoRequired(
        typeName: "[\(typeName)]",
        reason: "Array element type cannot be generated: \(reason)"
      )
    }
  }

  private func analyzeSetType(_ type: String) -> GeneratorTemplateResult? {
    guard type.hasPrefix("Set<") && type.hasSuffix(">") else {
      return nil
    }

    let inner = String(type.dropFirst(4).dropLast())
    let innerCheck = generatorTemplateResult(for: inner)

    switch innerCheck {
    case .success:
      return .success(
        .call(
          "Set",
          arguments: [
            .unlabeled(
              Template<Void>.variable("composer")
                .method("generate") {
                  TemplateArgument<Void>.labeled(
                    "using",
                    .variable("Gen").method("array") {
                      TemplateArgument<Void>.labeled("of", .property("arbitrary", on: inner))
                    }
                  )
                }
            )
          ]
        )
      )

    case .todoRequired(let typeName, let reason):
      return .todoRequired(
        typeName: "Set<\(typeName)>",
        reason: "Set element type cannot be generated: \(reason)"
      )
    }
  }

  private func isDictionaryType(_ type: String) -> Bool {
    type.hasPrefix("Dictionary<") || (type.hasPrefix("[") && type.contains(":"))
  }
}

extension TestCodeGenerator {
  func composerGenerateCall(for typeName: String) -> Template<Void> {
    Template<Void>.variable("composer")
      .method("generate") {
        TemplateArgument<Void>.labeled("using", .property("arbitrary", on: typeName))
      }
  }

  func composerGenerateOptionalCall(for expression: Template<Void>) -> Template<Void> {
    Template<Void>.variable("composer")
      .method("generate") {
        TemplateArgument<Void>.labeled(
          "using",
          .variable("Gen").method("optional") {
            TemplateArgument<Void>.unlabeled(expression)
          }
        )
      }
  }
}
