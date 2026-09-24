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
  case equatableNegation
  case hashableConsistency
  case comparableIrreflexive
  case comparableAsymmetric
  case comparableTransitive
  case comparableTrichotomy
  case comparableDerivedOperators
  case comparableMinMax
  case additiveZeroIdentity
  case losslessStringRoundtrip
  case rawRepresentableRoundtrip
  case sequenceUnderestimatedCount
  case collectionCountDistance
  case collectionEmptyBounds
  case collectionIndicesCount
  case bidirectionalIndexRoundtrip
  case setAlgebraIdempotence
  case setAlgebraUnionIdentity
  case setAlgebraAbsorption
  case setAlgebraDistributivity
  case setAlgebraSubsetDisjoint
  case setAlgebraSymmetricDifference
  case binaryIntegerBitwiseIdentity
  case binaryIntegerDeMorgan
  case fixedWidthByteSwap
  case fixedWidthOverflow
  case fixedWidthEndianRoundtrip
  case fixedWidthModularArithmetic
  case floatingPointNaN
  case caseIterableContainsValue
  case caseIterableStableCount
  case strideableZeroIdentity
  case optionSetBitwiseOperations
  case optionSetSymmetricDifferenceBits
  case optionSetMembershipMutation
  case randomAccessDistanceAntisymmetry
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
  /// The rendered `Generatable` extension.
  public let code: String
  /// Stored properties whose types need a user-supplied generator.
  public let todoProperties: [String]
  /// Whether every stored property received an executable generator.
  public var isFullyGenerated: Bool { todoProperties.isEmpty }

  /// Creates an arbitrary-generation result and its unresolved property list.
  public init(code: String, todoProperties: [String]) {
    self.code = code
    self.todoProperties = todoProperties
  }
}

// MARK: - Test Generator

/// Detects protocol laws and renders property tests for extracted Swift types.
public struct TestCodeGenerator {
  /// Creates a stateless test code generator.
  public init() {}

  static let knownGeneratableTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Bool", "String", "Character",
    "UUID", "Seed",
  ]
}

struct GeneratedTypeIdentity: Sendable {
  let reference: String
  let functionNameComponent: String
  let sectionTitle: String

  init(type: ExtractedTypeInfo, consumerModule: String? = nil) {
    let sourceName = type.sourceQualifiedName
    if sourceName.contains("."), let consumerModule {
      reference = "\(consumerModule).\(sourceName)"
    } else {
      reference = sourceName
    }
    let components =
      (consumerModule.map { [$0] } ?? [])
      + sourceName.split(separator: ".").map(String.init)
    functionNameComponent = components.map { "\($0.utf8.count)_\($0)" }
      .joined(separator: "_")
    sectionTitle = sourceName
  }
}

// MARK: - File Planning

extension TestCodeGenerator {
  /// Renders a generated test file for the supplied extracted types.
  public func generateTestFile(
    types: [ExtractedTypeInfo],
    sourceFile: String,
    consumerModule: String? = "InvariantSwift",
    discoverLaws: Bool = false
  ) -> String {
    GhostwriterExpansionRenderer.render(
      file: plannedFile(
        types: types,
        sourceFile: sourceFile,
        consumerModule: consumerModule,
        discoverLaws: discoverLaws
      )
    )
  }

  func plannedFile(
    types: [ExtractedTypeInfo],
    sourceFile: String,
    consumerModule: String? = "InvariantSwift",
    discoverLaws: Bool = false
  ) -> GhostwriterGeneratedFile {
    let fileName = URL(fileURLWithPath: sourceFile)
      .deletingPathExtension()
      .lastPathComponent

    return GhostwriterGeneratedFile(
      sourceFile: sourcePathForHeader(sourceFile),
      regenerationCommand: discoverLaws
        ? "swift package ghostwrite lawforge" : "swift package ghostwrite",
      imports: [
        GhostwriterImport(moduleName: "Testing"),
        GhostwriterImport(moduleName: "Foundation"),
        GhostwriterImport(moduleName: "InvariantSwiftTesting"),
        GhostwriterImport(moduleName: "InvariantSwiftMacroAPI"),
      ]
        + (consumerModule.map {
          [GhostwriterImport(moduleName: $0, isTestable: true)]
        } ?? [])
        + plannedSelectiveImports(for: types, consumerModule: consumerModule),
      arbitraryExtensions: plannedArbitraryExtensions(
        for: types,
        consumerModule: consumerModule
      ),
      suiteTitle: "\(fileName) Property Tests",
      suiteTypeName: suiteTypeName(for: sourceFile),
      sections: plannedSections(
        for: types,
        consumerModule: consumerModule,
        discoverLaws: discoverLaws
      )
    )
  }

  private func sourcePathForHeader(_ sourceFile: String) -> String {
    let absolutePath = URL(fileURLWithPath: sourceFile).standardizedFileURL.path
    let workingDirectory = URL(
      fileURLWithPath: FileManager.default.currentDirectoryPath
    ).standardizedFileURL.path
    let prefix = workingDirectory + "/"
    return absolutePath.hasPrefix(prefix)
      ? String(absolutePath.dropFirst(prefix.count)) : sourceFile
  }

  private func suiteTypeName(for sourceFile: String) -> String {
    let sourcePath = sourcePathForHeader(sourceFile)
    let hash = sourcePath.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
      ($0 ^ UInt64($1)) &* 1_099_511_628_211
    }
    return "GhostwriterSuite_\(String(hash, radix: 16))"
  }

  private func plannedSelectiveImports(
    for types: [ExtractedTypeInfo],
    consumerModule: String?
  ) -> [GhostwriterImport] {
    guard let consumerModule else { return [] }
    return types.compactMap { type in
      guard type.sourceQualifiedName == type.name,
        let kind = GhostwriterImport.DeclarationKind(extractedTypeKind: type.kind)
      else { return nil }
      return GhostwriterImport(
        moduleName: consumerModule,
        declarationKind: kind,
        declarationName: type.name
      )
    }
  }

  private func plannedArbitraryExtensions(
    for types: [ExtractedTypeInfo],
    consumerModule: String?
  ) -> [GhostwriterGeneratedArbitraryExtension] {
    let typesNeedingArbitrary = types.filter {
      !$0.hasArbitraryAttribute
        && !Self.knownGeneratableTypes.contains($0.name)
        && canAutoGenerateArbitrary(for: $0)
    }

    return typesNeedingArbitrary.map { type in
      plannedArbitraryExtension(
        for: type,
        identity: GeneratedTypeIdentity(type: type, consumerModule: consumerModule)
      )
    }
  }
}

private extension GhostwriterImport.DeclarationKind {
  init?(extractedTypeKind: String) {
    switch extractedTypeKind {
    case "actor", "class": self = .class
    case "enum": self = .enum
    case "struct": self = .struct
    default: return nil
    }
  }
}

// MARK: - Arbitrary Planning

extension TestCodeGenerator {
  /// Returns whether Ghostwriter can synthesize the complete generator safely.
  public func canAutoGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    canFullyGenerateArbitrary(for: type)
  }

  /// Returns whether every property in a supported concrete struct can be generated.
  public func canFullyGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    if type.kind == "enum" {
      return !type.enumCases.isEmpty && type.genericParameters.isEmpty
        && (type.accessLevel < .public || type.conformances.contains("Sendable"))
    }
    guard type.kind == "struct",
      type.genericParameters.isEmpty,
      !type.properties.isEmpty,
      type.accessLevel < .public || type.conformances.contains("Sendable"),
      type.properties.allSatisfy({ $0.accessLevel >= .internal })
    else { return false }
    guard type.properties.allSatisfy(isPropertyGeneratable) else { return false }

    let initializers = type.methods.filter { $0.name.hasPrefix("init") }
    return initializers.isEmpty
      || initializers.contains { initializer in
        initializer.name == "init"
          && initializer.accessLevel >= .internal
          && !initializer.isThrowing
          && !initializer.isAsync
          && initializer.parameters.map(\.label) == type.properties.map(\.name)
          && initializer.parameters.map(\.typeName) == type.properties.map(\.typeName)
      }
  }

  /// Renders a `Generatable` extension, including TODO placeholders when requested directly.
  public func generateArbitraryExtension(for type: ExtractedTypeInfo) -> String {
    generateArbitraryExtensionResult(for: type).code
  }

  /// Renders a `Generatable` extension and reports properties needing custom generators.
  public func generateArbitraryExtensionResult(
    for type: ExtractedTypeInfo
  ) -> ArbitraryGenerationResult {
    var todoProperties: [String] = []
    let arbitraryExtension = plannedArbitraryExtension(
      for: type,
      identity: GeneratedTypeIdentity(type: type),
      todoProperties: &todoProperties
    )

    return ArbitraryGenerationResult(
      code: GhostwriterExpansionRenderer.render(arbitraryExtension: arbitraryExtension),
      todoProperties: todoProperties
    )
  }

  func plannedArbitraryExtension(
    for type: ExtractedTypeInfo
  ) -> GhostwriterGeneratedArbitraryExtension {
    plannedArbitraryExtension(for: type, identity: GeneratedTypeIdentity(type: type))
  }

  private func plannedArbitraryExtension(
    for type: ExtractedTypeInfo,
    identity: GeneratedTypeIdentity
  ) -> GhostwriterGeneratedArbitraryExtension {
    var todoProperties: [String] = []
    return plannedArbitraryExtension(
      for: type,
      identity: identity,
      todoProperties: &todoProperties
    )
  }

  private func plannedArbitraryExtension(
    for type: ExtractedTypeInfo,
    identity: GeneratedTypeIdentity,
    todoProperties: inout [String]
  ) -> GhostwriterGeneratedArbitraryExtension {
    GhostwriterGeneratedArbitraryExtension(
      typeName: identity.reference,
      propertyGenerators: type.properties.map { property in
        buildPropertyGenerator(property, todoProperties: &todoProperties)
      },
      enumCases: type.enumCases
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
        expression: generator,
        todoComment: nil
      )

    case .todoRequired(let typeName, _):
      todoProperties.append(property.name)
      return GhostwriterPropertyGenerator(
        name: property.name,
        expression: .property("arbitrary", on: typeName),
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
  /// Resolves the generator expression for a Swift type spelling.
  public func generatorResult(for typeName: String) -> GeneratorResult {
    switch generatorTemplateResult(for: typeName) {
    case .success(let generator):
      return .success(GhostwriterExpansionRenderer.renderExpression(generator))

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
        .variable("OptionalGen").method(
          "optional",
          arguments: [.labeled("valueGen", generator)]
        )
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

    if let dictionaryResult = analyzeDictionaryType(cleanedType) {
      return dictionaryResult
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
    case .success(let elementGenerator):
      return .success(
        .variable("Gen<[\(inner)]>").method(
          "array",
          arguments: [.unlabeled(elementGenerator)]
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
    case .success(let elementGenerator):
      return .success(
        .variable("Gen<Set<\(inner)>>").method(
          "set",
          arguments: [.unlabeled(elementGenerator)]
        )
      )

    case .todoRequired(let typeName, let reason):
      return .todoRequired(
        typeName: "Set<\(typeName)>",
        reason: "Set element type cannot be generated: \(reason)"
      )
    }
  }

}
