// MARK: - Ghostwriter Tests
// Dog food tests for the ISP-0009 Ghostwriter module.

import Foundation
import Testing

import InvariantSwiftCore
@testable import InvariantSwift

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
    let config = GhostwriterConfig(
      sources: [],
      supportedArbitraryTypes: []
    )
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
