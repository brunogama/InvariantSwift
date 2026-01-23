// MARK: - Ghostwriter Arbitrary Generation Tests
// Tests for ISP-0009 Ghostwriter Arbitrary auto-generation with TODO tracking.

import Foundation
import Testing

@testable import InvariantSwift

@Suite("Ghostwriter GeneratorResult Tests")
struct GhostwriterGeneratorResultTests {

  @Test("GeneratorResult success for known primitive types")
  func generatorResultPrimitives() {
    let generator = TestCodeGenerator()

    let intResult = generator.generatorResult(for: "Int")
    if case .success(let expr) = intResult {
      #expect(expr.contains("Int.arbitrary"))
    } else {
      Issue.record("Expected success for Int")
    }

    let stringResult = generator.generatorResult(for: "String")
    if case .success(let expr) = stringResult {
      #expect(expr.contains("String.arbitrary"))
    } else {
      Issue.record("Expected success for String")
    }

    let boolResult = generator.generatorResult(for: "Bool")
    if case .success(let expr) = boolResult {
      #expect(expr.contains("Bool.arbitrary"))
    } else {
      Issue.record("Expected success for Bool")
    }
  }

  @Test("GeneratorResult success for optional types")
  func generatorResultOptional() {
    let generator = TestCodeGenerator()

    let optionalIntResult = generator.generatorResult(for: "Int?")
    if case .success(let expr) = optionalIntResult {
      #expect(expr.contains("Gen.optional"))
      #expect(expr.contains("Int.arbitrary"))
    } else {
      Issue.record("Expected success for Int?")
    }

    let optionalStringResult = generator.generatorResult(for: "String?")
    if case .success(let expr) = optionalStringResult {
      #expect(expr.contains("Gen.optional"))
      #expect(expr.contains("String.arbitrary"))
    } else {
      Issue.record("Expected success for String?")
    }
  }

  @Test("GeneratorResult success for array types")
  func generatorResultArray() {
    let generator = TestCodeGenerator()

    let arrayResult = generator.generatorResult(for: "[Int]")
    if case .success(let expr) = arrayResult {
      #expect(expr.contains("Gen.array"))
      #expect(expr.contains("Int.arbitrary"))
    } else {
      Issue.record("Expected success for [Int]")
    }

    let arrayGenericResult = generator.generatorResult(for: "Array<String>")
    if case .success(let expr) = arrayGenericResult {
      #expect(expr.contains("Gen.array"))
      #expect(expr.contains("String.arbitrary"))
    } else {
      Issue.record("Expected success for Array<String>")
    }
  }

  @Test("GeneratorResult success for set types")
  func generatorResultSet() {
    let generator = TestCodeGenerator()

    let setResult = generator.generatorResult(for: "Set<Int>")
    if case .success(let expr) = setResult {
      #expect(expr.contains("Set"))
      #expect(expr.contains("Gen.array"))
      #expect(expr.contains("Int.arbitrary"))
    } else {
      Issue.record("Expected success for Set<Int>")
    }
  }

  @Test("GeneratorResult todoRequired for dictionary types")
  func generatorResultDictionary() {
    let generator = TestCodeGenerator()

    let dictResult = generator.generatorResult(for: "[String: Int]")
    if case .todoRequired(let typeName, let reason) = dictResult {
      #expect(reason.contains("Dictionary"))
      #expect(reason.contains("not yet supported"))
    } else {
      Issue.record("Expected todoRequired for [String: Int]")
    }

    let dictGenericResult = generator.generatorResult(for: "Dictionary<String, Int>")
    if case .todoRequired = dictGenericResult {
      // Expected
    } else {
      Issue.record("Expected todoRequired for Dictionary<String, Int>")
    }
  }

  @Test("GeneratorResult todoRequired for unknown types")
  func generatorResultUnknown() {
    let generator = TestCodeGenerator()

    let customResult = generator.generatorResult(for: "MyCustomType")
    if case .todoRequired(let typeName, let reason) = customResult {
      #expect(typeName == "MyCustomType")
      #expect(reason.contains("does not have a known generator"))
    } else {
      Issue.record("Expected todoRequired for MyCustomType")
    }
  }

  @Test("GeneratorResult handles nested optional arrays")
  func generatorResultNestedOptionalArray() {
    let generator = TestCodeGenerator()

    let result = generator.generatorResult(for: "[Int]?")
    if case .success(let expr) = result {
      #expect(expr.contains("Gen.optional"))
      #expect(expr.contains("Gen.array") || expr.contains("[Int]"))
    } else {
      Issue.record("Expected success for [Int]?")
    }
  }

}

// MARK: - Arbitrary Generation Result and Helper Tests

@Suite("Ghostwriter Generation Result Tests")
struct GhostwriterGenerationResultTests {

  @Test("ArbitraryGenerationResult tracks fully generated types")
  func arbitraryGenerationFullyGenerated() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "SimpleStruct",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "id", typeName: "Int"),
        PropertyInfo(name: "name", typeName: "String"),
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    let result = generator.generateArbitraryExtensionResult(for: typeInfo)
    #expect(result.isFullyGenerated)
    #expect(result.todoProperties.isEmpty)
    #expect(result.code.contains("extension SimpleStruct: Arbitrary"))
  }

  @Test("ArbitraryGenerationResult tracks partial generation with TODOs")
  func arbitraryGenerationPartial() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "MixedStruct",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "id", typeName: "Int"),
        PropertyInfo(name: "custom", typeName: "CustomType"),
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    let result = generator.generateArbitraryExtensionResult(for: typeInfo)
    #expect(!result.isFullyGenerated)
    #expect(result.todoProperties.count == 1)
    #expect(result.todoProperties.contains("custom"))
    #expect(result.code.contains("TODO: supply generator for CustomType"))
  }

  @Test("ArbitraryGenerationResult handles all TODO properties")
  func arbitraryGenerationAllTODO() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "AllCustomStruct",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "custom1", typeName: "CustomType1"),
        PropertyInfo(name: "custom2", typeName: "CustomType2"),
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    let result = generator.generateArbitraryExtensionResult(for: typeInfo)
    #expect(!result.isFullyGenerated)
    #expect(result.todoProperties.count == 2)
    #expect(result.todoProperties.contains("custom1"))
    #expect(result.todoProperties.contains("custom2"))
  }

  @Test("canAutoGenerateArbitrary returns true for types with at least one generatable property")
  func canAutoGenerateSomeProperties() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "PartialStruct",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "id", typeName: "Int"),
        PropertyInfo(name: "custom", typeName: "UnknownType"),
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    #expect(generator.canAutoGenerateArbitrary(for: typeInfo))
  }

  @Test("canAutoGenerateArbitrary returns false for types with no generatable properties")
  func canAutoGenerateNoProperties() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "AllCustomStruct",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "custom1", typeName: "UnknownType1"),
        PropertyInfo(name: "custom2", typeName: "UnknownType2"),
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    #expect(!generator.canAutoGenerateArbitrary(for: typeInfo))
  }

  @Test("canFullyGenerateArbitrary returns true for types with all generatable properties")
  func canFullyGenerateAllProperties() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "FullyGeneratableStruct",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "id", typeName: "Int"),
        PropertyInfo(name: "name", typeName: "String"),
        PropertyInfo(name: "score", typeName: "Double"),
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    #expect(generator.canFullyGenerateArbitrary(for: typeInfo))
  }

  @Test("canFullyGenerateArbitrary returns false for types with some ungeneratable properties")
  func canFullyGenerateSomeUngeneratable() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "PartialStruct",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "id", typeName: "Int"),
        PropertyInfo(name: "custom", typeName: "CustomType"),
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    #expect(!generator.canFullyGenerateArbitrary(for: typeInfo))
  }

  @Test("Handles optional arrays")
  func optionalArrayGeneration() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "WithOptionalArray",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "items", typeName: "[String]?")
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    let result = generator.generateArbitraryExtensionResult(for: typeInfo)
    #expect(result.isFullyGenerated)
    #expect(result.code.contains("Gen.optional"))
  }

  @Test("Handles nested collections")
  func nestedCollections() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "WithNestedArray",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "matrix", typeName: "[[Int]]")
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    let result = generator.generateArbitraryExtensionResult(for: typeInfo)
    // Should handle nested arrays (even if currently generates TODO for inner array)
    #expect(!result.code.isEmpty)
  }

  @Test("Backward compatible generatorExpression emits TODO comments")
  func backwardCompatibleTODOComments() {
    let generator = TestCodeGenerator()

    let typeInfo = ExtractedTypeInfo(
      name: "WithCustomType",
      kind: .struct,
      sourceFile: "Test.swift",
      line: 1,
      conformances: [],
      properties: [
        PropertyInfo(name: "custom", typeName: "MyCustomType")
      ],
      hasArbitraryAttribute: false,
      isPublic: true
    )

    let code = generator.generateArbitraryExtension(for: typeInfo)
    #expect(code.contains("TODO: supply generator for MyCustomType"))
    #expect(code.contains("MyCustomType.arbitrary"))
  }
}
