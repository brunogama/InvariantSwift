// MARK: - Ghostwriter Tests
// Dog food tests for the ISP-0009 Ghostwriter module.

import Foundation
import Testing

@testable import InvariantSwift

// MARK: - TestPattern Tests

@Suite("TestPattern Tests")
struct TestPatternTests {

  @Test("All patterns have non-empty descriptions")
  func patternsHaveDescriptions() {
    for pattern in TestPattern.allCases {
      #expect(!pattern.description.isEmpty, "Pattern \(pattern.rawValue) should have description")
    }
  }

  @Test("All patterns have unique raw values")
  func patternsHaveUniqueRawValues() {
    let rawValues = TestPattern.allCases.map(\.rawValue)
    let uniqueRawValues = Set(rawValues)
    #expect(rawValues.count == uniqueRawValues.count, "All patterns should have unique raw values")
  }

  @Test("Equatable laws contains expected patterns")
  func equatableLawsPatterns() {
    let laws = TestPattern.equatableLaws
    #expect(laws.contains(.equatableReflexive))
    #expect(laws.contains(.equatableSymmetric))
    #expect(laws.contains(.equatableTransitive))
  }

  @Test("Comparable laws contains expected patterns")
  func comparableLawsPatterns() {
    let laws = TestPattern.comparableLaws
    #expect(laws.contains(.comparableIrreflexive))
    #expect(laws.contains(.comparableAsymmetric))
    #expect(laws.contains(.comparableTransitive))
    #expect(laws.contains(.comparableTrichotomy))
  }

  @Test("Numeric laws contains expected patterns")
  func numericLawsPatterns() {
    let laws = TestPattern.numericLaws
    #expect(laws.contains(.numericAdditiveIdentity))
    #expect(laws.contains(.numericCommutativity))
    #expect(laws.contains(.numericAssociativity))
  }

  @Test("Collection laws contains expected patterns")
  func collectionLawsPatterns() {
    let laws = TestPattern.collectionLaws
    #expect(laws.contains(.collectionCount))
    #expect(laws.contains(.collectionIndices))
    #expect(laws.contains(.collectionBounds))
  }
}

// MARK: - ProtocolConformance Tests

@Suite("ProtocolConformance Tests")
struct ProtocolConformanceTests {

  @Test("Codable conformance returns codableRoundtrip pattern")
  func codableApplicablePatterns() {
    let patterns = ProtocolConformance.codable.applicablePatterns
    #expect(patterns.contains(.codableRoundtrip))
  }

  @Test("Equatable conformance returns equatable law patterns")
  func equatableApplicablePatterns() {
    let patterns = ProtocolConformance.equatable.applicablePatterns
    #expect(patterns.contains(.equatableReflexive))
  }

  @Test("Hashable conformance returns hashableConsistency pattern")
  func hashableApplicablePatterns() {
    let patterns = ProtocolConformance.hashable.applicablePatterns
    #expect(patterns.contains(.hashableConsistency))
  }

  @Test("Comparable conformance returns comparable law patterns")
  func comparableApplicablePatterns() {
    let patterns = ProtocolConformance.comparable.applicablePatterns
    #expect(patterns.contains(.comparableIrreflexive))
  }

  @Test("Collection conformance returns collection patterns")
  func collectionApplicablePatterns() {
    let patterns = ProtocolConformance.collection.applicablePatterns
    #expect(patterns.contains(.collectionCount))
    #expect(patterns.contains(.collectionIndices))
  }

  @Test("All conformances have raw values")
  func allConformancesHaveRawValues() {
    for conformance in ProtocolConformance.allCases {
      #expect(!conformance.rawValue.isEmpty)
    }
  }
}

// MARK: - TypeKind Tests

@Suite("TypeKind Tests")
struct TypeKindTests {

  @Test("TypeKind raw values are correct")
  func typeKindRawValues() {
    #expect(TypeKind.structType.rawValue == "struct")
    #expect(TypeKind.classType.rawValue == "class")
    #expect(TypeKind.enumType.rawValue == "enum")
    #expect(TypeKind.actorType.rawValue == "actor")
    #expect(TypeKind.protocolType.rawValue == "protocol")
  }
}

// MARK: - PropertyInfo Tests

@Suite("PropertyInfo Tests")
struct PropertyInfoTests {

  @Test("PropertyInfo stores values correctly")
  func propertyInfoStoredValues() {
    let prop = PropertyInfo(
      name: "count",
      typeName: "Int",
      isOptional: false,
      isMutable: true,
      hasDefaultValue: true
    )

    #expect(prop.name == "count")
    #expect(prop.typeName == "Int")
    #expect(prop.isOptional == false)
    #expect(prop.isMutable == true)
    #expect(prop.hasDefaultValue == true)
  }

  @Test("Optional property detection")
  func optionalPropertyDetection() {
    let optionalProp = PropertyInfo(
      name: "value",
      typeName: "String?",
      isOptional: true,
      isMutable: false,
      hasDefaultValue: false
    )

    #expect(optionalProp.isOptional == true)
  }
}

// MARK: - MethodInfo Tests

@Suite("MethodInfo Tests")
struct MethodInfoTests {

  @Test("MethodInfo stores values correctly")
  func methodInfoStoredValues() {
    let method = MethodInfo(
      name: "calculate",
      parameters: [],
      returnType: "Int",
      isStatic: false,
      isMutating: false,
      isThrowing: false,
      isAsync: false
    )

    #expect(method.name == "calculate")
    #expect(method.returnType == "Int")
  }

  @Test("looksIdempotent detects idempotent methods")
  func looksIdempotentDetection() {
    let normalizeMethod = MethodInfo(
      name: "normalize",
      parameters: [],
      returnType: "Self",
      isStatic: false,
      isMutating: false,
      isThrowing: false,
      isAsync: false
    )
    #expect(normalizeMethod.looksIdempotent == true)

    let trimMethod = MethodInfo(
      name: "trimmed",
      parameters: [],
      returnType: "String",
      isStatic: false,
      isMutating: false,
      isThrowing: false,
      isAsync: false
    )
    #expect(trimMethod.looksIdempotent == true)

    let calculateMethod = MethodInfo(
      name: "calculate",
      parameters: [],
      returnType: "Int",
      isStatic: false,
      isMutating: false,
      isThrowing: false,
      isAsync: false
    )
    #expect(calculateMethod.looksIdempotent == false)
  }

  @Test("looksLikeEncoder detects encoder methods")
  func looksLikeEncoderDetection() {
    let encodeMethod = MethodInfo(
      name: "encode",
      parameters: [],
      returnType: "Data",
      isStatic: false,
      isMutating: false,
      isThrowing: true,
      isAsync: false
    )
    #expect(encodeMethod.looksLikeEncoder == true)

    let serializeMethod = MethodInfo(
      name: "serialize",
      parameters: [],
      returnType: "Data",
      isStatic: false,
      isMutating: false,
      isThrowing: false,
      isAsync: false
    )
    #expect(serializeMethod.looksLikeEncoder == true)
  }

  @Test("looksLikeDecoder detects decoder methods")
  func looksLikeDecoderDetection() {
    let decodeMethod = MethodInfo(
      name: "decode",
      parameters: [],
      returnType: "Self",
      isStatic: true,
      isMutating: false,
      isThrowing: true,
      isAsync: false
    )
    #expect(decodeMethod.looksLikeDecoder == true)
  }
}

// MARK: - TypeInfo Tests

@Suite("TypeInfo Tests")
struct TypeInfoTests {

  @Test("TypeInfo stores values correctly")
  func typeInfoStoredValues() {
    let typeInfo = TypeInfo(
      name: "User",
      kind: .structType,
      sourceFile: "User.swift",
      line: 10,
      conformances: [.equatable, .codable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    #expect(typeInfo.name == "User")
    #expect(typeInfo.kind == .structType)
    #expect(typeInfo.sourceFile == "User.swift")
    #expect(typeInfo.line == 10)
    #expect(typeInfo.conformances.count == 2)
  }

  @Test("fullName includes generic parameters")
  func fullNameWithGenerics() {
    let genericType = TypeInfo(
      name: "Container",
      kind: .structType,
      sourceFile: "Container.swift",
      line: 1,
      conformances: [],
      genericParameters: ["T", "U"],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    #expect(genericType.fullName == "Container<T, U>")
    #expect(genericType.isGeneric == true)
  }

  @Test("fullName without generic parameters")
  func fullNameWithoutGenerics() {
    let simpleType = TypeInfo(
      name: "Point",
      kind: .structType,
      sourceFile: "Point.swift",
      line: 1,
      conformances: [],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    #expect(simpleType.fullName == "Point")
    #expect(simpleType.isGeneric == false)
  }

  @Test("applicablePatterns returns patterns from conformances")
  func applicablePatternsFromConformances() {
    let typeInfo = TypeInfo(
      name: "Value",
      kind: .structType,
      sourceFile: "Value.swift",
      line: 1,
      conformances: [.equatable, .codable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let patterns = typeInfo.applicablePatterns
    #expect(patterns.contains(.equatableReflexive))
    #expect(patterns.contains(.codableRoundtrip))
  }

  @Test("canGenerateArbitrary with conformances")
  func canGenerateArbitraryWithConformances() {
    let typeWithConformances = TypeInfo(
      name: "Value",
      kind: .structType,
      sourceFile: "Value.swift",
      line: 1,
      conformances: [.equatable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    #expect(typeWithConformances.canGenerateArbitrary == true)
  }
}

// MARK: - SourceFileInfo Tests

@Suite("SourceFileInfo Tests")
struct SourceFileInfoTests {

  @Test("SourceFileInfo stores values correctly")
  func sourceFileInfoStoredValues() {
    let fileInfo = SourceFileInfo(
      path: "/path/to/file.swift",
      types: [],
      imports: ["Foundation", "Testing"],
      hash: "abc123"
    )

    #expect(fileInfo.path == "/path/to/file.swift")
    #expect(fileInfo.imports.count == 2)
    #expect(fileInfo.hash == "abc123")
    #expect(fileInfo.typeCount == 0)
  }

  @Test("testableTypes filters by applicable patterns")
  func testableTypesFiltering() {
    let testableType = TypeInfo(
      name: "User",
      kind: .structType,
      sourceFile: "User.swift",
      line: 1,
      conformances: [.equatable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let nonTestableType = TypeInfo(
      name: "Internal",
      kind: .structType,
      sourceFile: "Internal.swift",
      line: 1,
      conformances: [.sendable],  // No patterns for Sendable
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let fileInfo = SourceFileInfo(
      path: "/path/to/file.swift",
      types: [testableType, nonTestableType],
      imports: [],
      hash: "xyz"
    )

    #expect(fileInfo.testableTypes.count == 1)
    #expect(fileInfo.testableTypes.first?.name == "User")
  }
}

// MARK: - GhostwriterConfig Tests

@Suite("GhostwriterConfig Tests")
struct GhostwriterConfigTests {

  @Test("Default config has expected values")
  func defaultConfigValues() {
    let config = GhostwriterConfig.default
    #expect(config.sources.isEmpty)
    #expect(config.outputDirectory == "Tests/Generated/")
    #expect(config.patterns.isEmpty)
    #expect(config.dryRun == false)
    #expect(config.verbose == false)
    #expect(config.testPrefix == "test")
    #expect(config.testSuffix == "PropertyTests")
  }

  @Test("Custom config stores values")
  func customConfigValues() {
    let config = GhostwriterConfig(
      sources: ["Sources/MyLib"],
      outputDirectory: "CustomTests/",
      patterns: [.codableRoundtrip],
      excludePatterns: ["*.generated.swift"],
      dryRun: true,
      verbose: true,
      force: true,
      testPrefix: "verify_",
      testSuffix: "_Props"
    )

    #expect(config.sources.count == 1)
    #expect(config.outputDirectory == "CustomTests/")
    #expect(config.patterns.count == 1)
    #expect(config.excludePatterns.count == 1)
    #expect(config.dryRun == true)
    #expect(config.verbose == true)
    #expect(config.force == true)
    #expect(config.testPrefix == "verify_")
    #expect(config.testSuffix == "_Props")
  }
}

// MARK: - GeneratedTest Tests

@Suite("GeneratedTest Tests")
struct GeneratedTestTests {

  @Test("GeneratedTest stores values correctly")
  func generatedTestStoredValues() {
    let test = GeneratedTest(
      name: "test_User_equatableReflexive",
      sourceFile: "User.swift",
      sourceLine: 10,
      typeName: "User",
      pattern: "equatable_reflexive",
      code: "@PropertyTest func test() { }"
    )

    #expect(test.name == "test_User_equatableReflexive")
    #expect(test.sourceFile == "User.swift")
    #expect(test.sourceLine == 10)
    #expect(test.typeName == "User")
    #expect(test.pattern == "equatable_reflexive")
    #expect(!test.code.isEmpty)
  }

  @Test("GeneratedTest is Codable")
  func generatedTestCodable() throws {
    let test = GeneratedTest(
      name: "test_Value_codable",
      sourceFile: "Value.swift",
      sourceLine: 5,
      typeName: "Value",
      pattern: "codable_roundtrip",
      code: "// test code"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(test)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(GeneratedTest.self, from: data)

    #expect(decoded.name == test.name)
    #expect(decoded.typeName == test.typeName)
    #expect(decoded.pattern == test.pattern)
  }
}

// MARK: - GhostwriterError Tests

@Suite("GhostwriterError Tests")
struct GhostwriterErrorTests {

  @Test("Error descriptions are meaningful")
  func errorDescriptions() {
    let fileNotFound = GhostwriterError.fileNotFound("/path/to/missing.swift")
    #expect(fileNotFound.description.contains("missing.swift"))

    let parseError = GhostwriterError.parseError(file: "bad.swift", message: "Syntax error")
    #expect(parseError.description.contains("bad.swift"))
    #expect(parseError.description.contains("Syntax error"))

    let noTypes = GhostwriterError.noTypesFound("Sources/")
    #expect(noTypes.description.contains("Sources/"))

    let writeError = GhostwriterError.writeError(file: "output.swift", message: "Permission denied")
    #expect(writeError.description.contains("output.swift"))

    let configError = GhostwriterError.configurationError("Invalid pattern")
    #expect(configError.description.contains("Invalid pattern"))
  }
}

// MARK: - GhostwriterResult Tests

@Suite("GhostwriterResult Tests")
struct GhostwriterResultTests {

  @Test("GhostwriterResult summary is correct")
  func resultSummary() {
    let result = GhostwriterResult(
      analyzedFiles: ["file1.swift", "file2.swift"],
      discoveredTypes: [],
      generatedTests: [],
      errors: []
    )

    let summary = result.summary
    #expect(summary.contains("2"))  // analyzed files count
    #expect(summary.contains("0"))  // discovered types count
  }
}

// MARK: - GhostwriterManifest Tests

@Suite("GhostwriterManifest Tests")
struct GhostwriterManifestTests {

  @Test("Manifest initializes with correct version")
  func manifestVersion() {
    let manifest = GhostwriterManifest(
      sourceHash: "abc123",
      tests: []
    )

    #expect(manifest.version == "1.0")
  }

  @Test("Manifest is Codable roundtrip")
  func manifestCodable() throws {
    let test = GeneratedTest(
      name: "test_Example",
      sourceFile: "Example.swift",
      sourceLine: 1,
      typeName: "Example",
      pattern: "codable_roundtrip",
      code: "// code"
    )

    let manifest = GhostwriterManifest(
      sourceHash: "xyz789",
      tests: [test]
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(manifest)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(GhostwriterManifest.self, from: data)

    #expect(decoded.sourceHash == manifest.sourceHash)
    #expect(decoded.tests.count == 1)
    #expect(decoded.version == "1.0")
  }
}

// MARK: - TestGenerator Tests

@Suite("TestGenerator Tests")
struct TestGeneratorTests {

  @Test("TestGenerator generates tests for type with patterns")
  func generateTestsForType() {
    let config = GhostwriterConfig(sources: [])
    let generator = TestGenerator(config: config)

    let typeInfo = TypeInfo(
      name: "User",
      kind: .structType,
      sourceFile: "User.swift",
      line: 10,
      conformances: [.equatable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let tests = generator.generateTests(for: typeInfo)
    #expect(!tests.isEmpty)
  }

  @Test("TestGenerator generates correct test for Codable pattern")
  func generateCodableTest() {
    let config = GhostwriterConfig(sources: [])
    let generator = TestGenerator(config: config)

    let typeInfo = TypeInfo(
      name: "Message",
      kind: .structType,
      sourceFile: "Message.swift",
      line: 5,
      conformances: [.codable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let test = generator.generateTest(for: typeInfo, pattern: .codableRoundtrip)
    #expect(test != nil)
    #expect(test?.code.contains("JSONEncoder") == true)
    #expect(test?.code.contains("JSONDecoder") == true)
    #expect(test?.pattern == "codable_roundtrip")
  }

  @Test("TestGenerator generates correct test for Equatable pattern")
  func generateEquatableTest() {
    let config = GhostwriterConfig(sources: [])
    let generator = TestGenerator(config: config)

    let typeInfo = TypeInfo(
      name: "Point",
      kind: .structType,
      sourceFile: "Point.swift",
      line: 1,
      conformances: [.equatable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let test = generator.generateTest(for: typeInfo, pattern: .equatableReflexive)
    #expect(test != nil)
    #expect(test?.code.contains("value == value") == true)
    #expect(test?.pattern == "equatable_reflexive")
  }

  @Test("TestGenerator uses custom test prefix")
  func customTestPrefix() {
    let config = GhostwriterConfig(
      sources: [],
      testPrefix: "verify_"
    )
    let generator = TestGenerator(config: config)

    let typeInfo = TypeInfo(
      name: "Data",
      kind: .structType,
      sourceFile: "Data.swift",
      line: 1,
      conformances: [.equatable],
      genericParameters: [],
      properties: [],
      methods: [],
      hasFailableInit: false,
      hasPublicInit: true
    )

    let test = generator.generateTest(for: typeInfo, pattern: .equatableReflexive)
    #expect(test?.code.contains("verify_") == true)
  }
}
