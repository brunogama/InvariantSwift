// MARK: - Test Code Generator
// Generates property test plans from extracted type information.

import Foundation
import InvariantSwiftExpansionSupport

// MARK: - Test Pattern

/// Test patterns that can be generated.
public enum GhostwriterTestPattern: String, CaseIterable, Codable, Sendable {
  case codableRoundtrip
  case equatableReflexive
  case equatableSymmetric
  case equatableTransitive
  case hashableConsistency
  case comparableIrreflexive
  case comparableAsymmetric
  case comparableTransitive
  case comparableTrichotomy

  public static var equatableLaws: [Self] {
    [.equatableReflexive, .equatableSymmetric, .equatableTransitive]
  }

  public static var comparableLaws: [Self] {
    [.comparableIrreflexive, .comparableAsymmetric, .comparableTransitive, .comparableTrichotomy]
  }
}

// MARK: - Generator Result

/// Result of attempting to generate an Arbitrary conformance for a property.
public enum GeneratorResult: Sendable {
  case success(String)
  case todoRequired(typeName: String, reason: String)
}

enum GeneratorTemplateResult {
  case success(ExpansionExpr)
  case todoRequired(typeName: String, reason: String)
}

/// Result of generating an Arbitrary extension with TODO tracking.
public struct ArbitraryGenerationResult: Sendable {
  public let code: String
  public let todoProperties: [String]
  public var isFullyGenerated: Bool { todoProperties.isEmpty }

  public init(code: String, todoProperties: [String]) {
    self.code = code
    self.todoProperties = todoProperties
  }
}

// MARK: - Test Generator

public struct TestCodeGenerator {
  public init() {}

  static let knownGeneratableTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Bool", "String", "Character",
    "Date", "UUID", "URL", "Data", "Seed", "Size",
  ]
}

// MARK: - Pattern Detection

extension TestCodeGenerator {
  public func isKnownGeneratableType(_ name: String) -> Bool {
    Self.knownGeneratableTypes.contains(name)
  }

  public func detectPatterns(for type: ExtractedTypeInfo) -> [GhostwriterTestPattern] {
    var patterns = Set<GhostwriterTestPattern>()

    for conformance in type.conformances {
      addPatternsFor(conformance: conformance, type: type, to: &patterns)
    }

    return Array(patterns).sorted { $0.rawValue < $1.rawValue }
  }

  private func addPatternsFor(
    conformance: String,
    type: ExtractedTypeInfo,
    to patterns: inout Set<GhostwriterTestPattern>
  ) {
    switch conformance {
    case "Codable":
      if type.conformances.contains("Equatable") || type.conformances.contains("Hashable") {
        patterns.insert(.codableRoundtrip)
      }

    case "Equatable":
      GhostwriterTestPattern.equatableLaws.forEach { patterns.insert($0) }

    case "Hashable":
      patterns.insert(.hashableConsistency)
      GhostwriterTestPattern.equatableLaws.forEach { patterns.insert($0) }

    case "Comparable":
      GhostwriterTestPattern.comparableLaws.forEach { patterns.insert($0) }

    default:
      break
    }
  }
}

// MARK: - File Planning

extension TestCodeGenerator {
  public func generateTestFile(
    types: [ExtractedTypeInfo],
    sourceFile: String
  ) -> String {
    GhostwriterExpansionRenderer.render(file: plannedFile(types: types, sourceFile: sourceFile))
  }

  func plannedFile(
    types: [ExtractedTypeInfo],
    sourceFile: String
  ) -> GhostwriterGeneratedFile {
    let fileName = URL(fileURLWithPath: sourceFile)
      .deletingPathExtension()
      .lastPathComponent

    return GhostwriterGeneratedFile(
      sourceFile: sourceFile,
      generatedAt: ISO8601DateFormatter().string(from: Date()),
      imports: [
        GhostwriterImport(moduleName: "Testing"),
        GhostwriterImport(moduleName: "Foundation"),
        GhostwriterImport(moduleName: "InvariantSwiftTesting"),
        GhostwriterImport(moduleName: "InvariantSwiftMacroAPI"),
        GhostwriterImport(moduleName: "InvariantSwift", isTestable: true),
      ],
      arbitraryExtensions: plannedArbitraryExtensions(for: types),
      suiteTitle: "\(fileName) Property Tests",
      sections: plannedSections(for: types)
    )
  }

  private func plannedArbitraryExtensions(
    for types: [ExtractedTypeInfo]
  ) -> [GhostwriterGeneratedArbitraryExtension] {
    let typesNeedingArbitrary = types.filter {
      !$0.hasArbitraryAttribute
        && !$0.properties.isEmpty
        && !Self.knownGeneratableTypes.contains($0.name)
    }

    return typesNeedingArbitrary.map(plannedArbitraryExtension(for:))
  }

  private func plannedSections(for types: [ExtractedTypeInfo]) -> [GhostwriterGeneratedSection] {
    types.compactMap { type in
      let tests = detectPatterns(for: type).map { plannedTest(for: type, pattern: $0) }
      guard !tests.isEmpty else { return nil }
      return GhostwriterGeneratedSection(title: type.name, tests: tests)
    }
  }
}

// MARK: - Arbitrary Planning

extension TestCodeGenerator {
  public func canAutoGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    guard !type.properties.isEmpty else { return false }
    return type.properties.contains { isPropertyGeneratable($0) }
  }

  public func canFullyGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    guard !type.properties.isEmpty else { return false }
    return type.properties.allSatisfy { isPropertyGeneratable($0) }
  }

  public func generateArbitraryExtension(for type: ExtractedTypeInfo) -> String {
    generateArbitraryExtensionResult(for: type).code
  }

  public func generateArbitraryExtensionResult(
    for type: ExtractedTypeInfo
  ) -> ArbitraryGenerationResult {
    var todoProperties: [String] = []
    let arbitraryExtension = plannedArbitraryExtension(for: type, todoProperties: &todoProperties)

    return ArbitraryGenerationResult(
      code: GhostwriterExpansionRenderer.render(arbitraryExtension: arbitraryExtension),
      todoProperties: todoProperties
    )
  }

  func plannedArbitraryExtension(
    for type: ExtractedTypeInfo
  ) -> GhostwriterGeneratedArbitraryExtension {
    var todoProperties: [String] = []
    return plannedArbitraryExtension(for: type, todoProperties: &todoProperties)
  }

  private func plannedArbitraryExtension(
    for type: ExtractedTypeInfo,
    todoProperties: inout [String]
  ) -> GhostwriterGeneratedArbitraryExtension {
    GhostwriterGeneratedArbitraryExtension(
      typeName: type.name,
      propertyGenerators: type.properties.map { property in
        buildPropertyGenerator(property, todoProperties: &todoProperties)
      }
    )
  }

  private func buildPropertyGenerator(
    _ property: ExtractedProperty,
    todoProperties: inout [String]
  ) -> GhostwriterPropertyGenerator {
    switch generatorTemplateResult(for: property.typeName) {
    case .success(let generator):
      return GhostwriterPropertyGenerator(
        name: property.name,
        expression: composerGenerate(using: generator),
        todoComment: nil
      )

    case .todoRequired(let typeName, _):
      todoProperties.append(property.name)
      return GhostwriterPropertyGenerator(
        name: property.name,
        expression: composerGenerate(using: .property("arbitrary", on: typeName)),
        todoComment: "/* TODO: supply generator for \(typeName) */"
      )
    }
  }

  private func isPropertyGeneratable(_ property: ExtractedProperty) -> Bool {
    if case .success = generatorTemplateResult(for: property.typeName) {
      return true
    }
    return false
  }
}

// MARK: - Generator Planning

extension TestCodeGenerator {
  public func generatorResult(for typeName: String) -> GeneratorResult {
    switch generatorTemplateResult(for: typeName) {
    case .success(let generator):
      return .success(
        GhostwriterExpansionRenderer.renderExpression(composerGenerate(using: generator))
      )

    case .todoRequired(let missingType, let reason):
      return .todoRequired(typeName: missingType, reason: reason)
    }
  }

  func generatorTemplateResult(for typeName: String) -> GeneratorTemplateResult {
    let cleanedType = cleanTypeName(typeName)
    let isOptional = typeName.contains("?") || typeName.hasPrefix("Optional<")
    let result = analyzeType(cleanedType)

    if isOptional, case .success(let generator) = result {
      return .success(
        .variable("Gen").method("optional", arguments: [.unlabeled(generator)])
      )
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
      return .success(.property("arbitrary", on: cleanedType))
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
    switch generatorTemplateResult(for: inner) {
    case .success:
      return .success(
        .variable("Gen").method(
          "array",
          arguments: [.labeled("of", .property("arbitrary", on: inner))]
        )
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

    switch generatorTemplateResult(for: inner) {
    case .success:
      return .success(
        .call(
          "Set",
          arguments: [
            .unlabeled(
              composerGenerate(
                using: .variable("Gen").method(
                  "array",
                  arguments: [.labeled("of", .property("arbitrary", on: inner))]
                )
              )
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

  func composerGenerate(using generator: ExpansionExpr) -> ExpansionExpr {
    ExpansionExpr.variable("composer")
      .method("generate", arguments: [.labeled("using", generator)])
  }
}
