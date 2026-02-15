// MARK: - TestCodeGenerator Generator Result Analysis
// Type analysis for generator expression generation.

import Foundation

extension TestCodeGenerator {
  /// Determine generator result for a property type.
  public func generatorResult(for typeName: String) -> GeneratorResult {
    let cleanedType = cleanTypeName(typeName)
    let isOptional = typeName.contains("?") || typeName.hasPrefix("Optional<")

    let result = analyzeType(cleanedType)

    if isOptional, case .success = result {
      return .success("composer.generate(using: Gen.optional(\(cleanedType).arbitrary))")
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

  private func analyzeType(_ cleanedType: String) -> GeneratorResult {
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
      return .success("composer.generate(using: \(cleanedType).arbitrary)")
    }

    return .todoRequired(
      typeName: cleanedType,
      reason: "Type does not have a known generator"
    )
  }

  private func analyzeArrayType(_ type: String) -> GeneratorResult? {
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

  private func handleArrayElement(_ inner: String) -> GeneratorResult {
    let innerCheck = generatorResult(for: inner)

    switch innerCheck {
    case .success:
      return .success("composer.generate(using: Gen.array(of: \(inner).arbitrary))")

    case .todoRequired(let typeName, let reason):
      return .todoRequired(
        typeName: "[\(typeName)]",
        reason: "Array element type cannot be generated: \(reason)"
      )
    }
  }

  private func analyzeSetType(_ type: String) -> GeneratorResult? {
    guard type.hasPrefix("Set<") && type.hasSuffix(">") else {
      return nil
    }

    let inner = String(type.dropFirst(4).dropLast())
    let innerCheck = generatorResult(for: inner)

    switch innerCheck {
    case .success:
      return .success("Set(composer.generate(using: Gen.array(of: \(inner).arbitrary)))")

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
