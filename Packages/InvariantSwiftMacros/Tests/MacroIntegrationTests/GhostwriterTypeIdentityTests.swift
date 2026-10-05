import Testing

@testable import GhostwriterLib

@Suite("Ghostwriter type identity")
struct GhostwriterTypeIdentityTests {
  private let extractor = SwiftSyntaxTypeExtractor()
  private let generator = TestCodeGenerator()

  @Test("Nested declarations use module-qualified references and lexical test names")
  func nestedTypeReferences() throws {
    let analysis = extractor.analyze(
      source: """
        public actor TelemetrySystem {
          public enum EventType: Equatable, CaseIterable, Sendable {
            case started
            case stopped
          }
        }
        """,
      filePath: "Sources/InvariantSwiftAdvanced/TelemetrySystem.swift"
    )
    let eventType = try #require(analysis.types.first { $0.name == "EventType" })

    let code = generator.generateTestFile(
      types: [eventType],
      sourceFile: eventType.sourceFile,
      consumerModule: "InvariantSwiftAdvanced"
    )

    #expect(code.contains("InvariantSwiftAdvanced.TelemetrySystem.EventType"))
    #expect(
      code.contains(
        "Gen.pure(InvariantSwiftAdvanced.TelemetrySystem.EventType.started)"
      )
    )
    #expect(
      code.contains(
        "func test22_InvariantSwiftAdvanced_15_TelemetrySystem_9_EventType_equatableReflexive"
      )
    )
    #expect(!code.contains("func testTelemetrySystem.EventType"))
    #expect(CompileVerifier().verifySyntax(code: code, fileName: "EventTypeTests.swift").success)
  }

  @Test("Nested references remain unambiguous when an imported module repeats the root name")
  func nestedRootCollision() throws {
    let analysis = extractor.analyze(
      source: """
        public struct FailureReport: Sendable {
          public enum Outcome: Equatable, Sendable {
            case failed
            case gaveUp
          }
        }
        """,
      filePath: "Sources/InvariantSwiftCore/FailureReport.swift"
    )
    let outcome = try #require(analysis.types.first { $0.name == "Outcome" })

    let code = generator.generateTestFile(
      types: [outcome],
      sourceFile: outcome.sourceFile,
      consumerModule: "InvariantSwiftCore"
    )

    #expect(code.contains("import InvariantSwiftTesting"))
    #expect(code.contains("InvariantSwiftCore.FailureReport.Outcome"))
    #expect(!code.contains("value: FailureReport.Outcome"))
    #expect(
      code.contains("func test18_InvariantSwiftCore_13_FailureReport_7_Outcome_equatableReflexive")
    )
  }

  @Test("Nested declarations in generic ancestors remain ineligible")
  func nestedGenericTypeEligibility() throws {
    let analysis = extractor.analyze(
      source: """
        struct Box<Element> {
          enum State: Equatable, CaseIterable, Sendable {
            case empty
          }
        }
        """,
      filePath: "Sources/Fixtures/Box.swift"
    )
    let state = try #require(analysis.types.first { $0.name == "State" })

    #expect(generator.generatedTestCount(for: state) == 0)
    #expect(!generator.canAutoGenerateArbitrary(for: state))
  }

  @Test("Mangled test names distinguish underscores from nested type boundaries")
  func mangledTypeNames() throws {
    let analysis = extractor.analyze(
      source: "struct A_B {}\nstruct A { struct B {} }",
      filePath: "Fixtures/Names.swift"
    )
    let flat = try #require(analysis.types.first { $0.name == "A_B" })
    let nested = try #require(analysis.types.first { $0.name == "B" })

    let flatName = GeneratedTypeIdentity(type: flat, consumerModule: "Fixture")
    let nestedName = GeneratedTypeIdentity(type: nested, consumerModule: "Fixture")

    #expect(flatName.functionNameComponent == "7_Fixture_3_A_B")
    #expect(nestedName.functionNameComponent == "7_Fixture_1_A_1_B")
  }

  @Test("Extension conformances stay inside their SwiftPM module")
  func moduleScopedExtensionConformances() throws {
    let declaration = extractor.analyze(
      source: "struct Collision: Equatable {}",
      filePath: "Sources/ModuleA/Collision.swift"
    )
    let sameModuleExtension = extractor.analyze(
      source: "extension Collision: Hashable {}",
      filePath: "Sources/ModuleA/Collision+Hashable.swift"
    )
    let otherModuleExtension = extractor.analyze(
      source: "extension Collision: CaseIterable {}",
      filePath: "Sources/ModuleB/Collision+CaseIterable.swift"
    )
    let extensions = sameModuleExtension.extensionConformances.merging(
      otherModuleExtension.extensionConformances,
      uniquingKeysWith: +
    )

    let merged = SwiftSyntaxTypeExtractor.mergeConformances(
      types: declaration.types,
      extensions: extensions
    )
    let collision = try #require(merged.first)

    #expect(Set(collision.conformances) == ["Equatable", "Hashable"])
  }

  @Test("Top-level references use selective imports to avoid imported collisions")
  func selectivelyImportedTopLevelReference() {
    let type = ExtractedTypeInfo(
      name: "ErrorBehavior",
      kind: "enum",
      sourceFile: "Sources/InvariantSwift/ErrorBehavior.swift",
      line: 1,
      conformances: ["Equatable"],
      hasArbitraryAttribute: true,
      properties: [],
      methods: [],
      genericParameters: [],
      accessLevel: .public,
      enumCases: ["failFast", "accumulate"]
    )

    let code = generator.generateTestFile(
      types: [type],
      sourceFile: type.sourceFile,
      consumerModule: "InvariantSwift"
    )

    #expect(code.contains("import enum InvariantSwift.ErrorBehavior"))
    #expect(
      code.contains(
        "func test14_InvariantSwift_13_ErrorBehavior_equatableReflexive(value: ErrorBehavior)"
      )
    )
    #expect(!code.contains("value: InvariantSwift.ErrorBehavior"))
    #expect(
      CompileVerifier().verifySyntax(code: code, fileName: "ErrorBehaviorTests.swift").success
    )
  }

  @Test("Selective imports avoid module and type name shadowing")
  func moduleNameShadowing() {
    let type = ExtractedTypeInfo(
      name: "GeneratorCategory",
      kind: "enum",
      sourceFile: "Sources/GeneratorCatalogCLI/CatalogBrowser.swift",
      line: 1,
      conformances: ["Equatable", "CaseIterable", "Sendable"],
      hasArbitraryAttribute: false,
      properties: [],
      methods: [],
      genericParameters: [],
      accessLevel: .public,
      enumCases: ["primitive", "custom"]
    )

    let code = generator.generateTestFile(
      types: [type],
      sourceFile: type.sourceFile,
      consumerModule: "GeneratorCatalogCLI"
    )

    #expect(code.contains("import enum GeneratorCatalogCLI.GeneratorCategory"))
    #expect(code.contains("extension GeneratorCategory:"))
    #expect(code.contains("value: GeneratorCategory"))
    #expect(!code.contains("extension GeneratorCatalogCLI.GeneratorCategory"))
  }

  @Test("Nested operators retain their expression grouping")
  func nestedOperatorGrouping() {
    let type = ExtractedTypeInfo(
      name: "AccessLevel",
      kind: "enum",
      sourceFile: "Sources/GhostwriterLib/AccessLevel.swift",
      line: 1,
      conformances: ["Comparable", "CaseIterable", "Sendable"],
      hasArbitraryAttribute: false,
      properties: [],
      methods: [],
      genericParameters: [],
      accessLevel: .public,
      enumCases: ["internal", "public"]
    )

    let code = generator.generateTestFile(
      types: [type],
      sourceFile: type.sourceFile,
      consumerModule: "GhostwriterLib"
    )

    #expect(code.contains("#expect(!(b < a),"))
    #expect(code.contains("#expect(!(value < value),"))
    #expect(code.contains("#expect((a > b) == (b < a),"))
    #expect(code.contains("#expect((a >= b) == (b <= a),"))
  }
}
