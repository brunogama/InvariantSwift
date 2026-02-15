// MARK: - Test Code Generator
// Generates property test code from extracted type information.

import Foundation

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

/// Generates property test code from extracted types.
public struct TestCodeGenerator {
  public init() {}

  /// Known types that have built-in generators.
  static let knownGeneratableTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Bool", "String", "Character",
    "Date", "UUID", "URL", "Data", "Seed", "Size",
  ]
}

// MARK: - Pattern Detection

extension TestCodeGenerator {
  /// Detect applicable test patterns for a type based on conformances.
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

// MARK: - Arbitrary Generation

extension TestCodeGenerator {
  /// Check if a type can have Arbitrary auto-generated.
  public func canAutoGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    guard !type.properties.isEmpty else { return false }
    return type.properties.contains { isPropertyGeneratable($0) }
  }

  /// Check if a type can be fully auto-generated.
  public func canFullyGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    guard !type.properties.isEmpty else { return false }
    return type.properties.allSatisfy { isPropertyGeneratable($0) }
  }

  private func isPropertyGeneratable(_ prop: ExtractedProperty) -> Bool {
    if case .success = generatorResult(for: prop.typeName) {
      return true
    }
    return false
  }

  /// Generate Arbitrary extension for a type.
  public func generateArbitraryExtension(for type: ExtractedTypeInfo) -> String {
    generateArbitraryExtensionResult(for: type).code
  }

  /// Generate Arbitrary extension with TODO tracking.
  public func generateArbitraryExtensionResult(
    for type: ExtractedTypeInfo
  ) -> ArbitraryGenerationResult {
    var todoProperties: [String] = []
    let propGenerators = type.properties.map { prop in
      buildPropertyGenerator(prop, todoProperties: &todoProperties)
    }

    let code = """
      extension \(type.name): Arbitrary {
        public static var arbitrary: Gen<\(type.name)> {
          Gen.compose { composer in
            \(type.name)(
              \(propGenerators.joined(separator: ",\n        "))
            )
          }
        }
      }
      """

    return ArbitraryGenerationResult(code: code, todoProperties: todoProperties)
  }

  private func buildPropertyGenerator(
    _ prop: ExtractedProperty,
    todoProperties: inout [String]
  ) -> String {
    let result = generatorResult(for: prop.typeName)

    switch result {
    case .success(let expr):
      return "\(prop.name): \(expr)"

    case .todoRequired(let typeName, _):
      todoProperties.append(prop.name)
      let todoComment = "/* TODO: supply generator for \(typeName) */"
      return "\(prop.name): \(todoComment) composer.generate(using: \(typeName).arbitrary)"
    }
  }
}
