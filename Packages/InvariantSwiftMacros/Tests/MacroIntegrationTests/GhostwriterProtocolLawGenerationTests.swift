import Testing

@testable import GhostwriterLib

@Suite("Ghostwriter Protocol Law Generation")
struct GhostwriterProtocolLawGenerationTests {
  private let generator = TestCodeGenerator()

  @Test("FixedWidthInteger inherits executable value laws deterministically")
  func fixedWidthIntegerInheritance() {
    let patterns = generator.detectPatterns(
      for: type(
        "Counter",
        conformances: ["FixedWidthInteger"]
      )
    )

    #expect(
      patterns == [
        .additiveZeroIdentity,
        .binaryIntegerBitwiseIdentity,
        .binaryIntegerDeMorgan,
        .comparableAsymmetric,
        .comparableDerivedOperators,
        .comparableIrreflexive,
        .comparableMinMax,
        .comparableTransitive,
        .comparableTrichotomy,
        .equatableNegation,
        .equatableReflexive,
        .equatableSymmetric,
        .fixedWidthByteSwap,
        .fixedWidthEndianRoundtrip,
        .fixedWidthModularArithmetic,
        .fixedWidthOverflow,
        .losslessStringRoundtrip,
        .strideableZeroIdentity,
      ]
    )
  }

  @Test("FloatingPoint emits NaN law and omits IEEE-unsafe exact laws")
  func floatingPointExclusions() {
    let patterns = generator.detectPatterns(
      for: type(
        "Scalar",
        conformances: ["BinaryFloatingPoint"]
      )
    )

    #expect(patterns.contains(.floatingPointNaN))
    #expect(!patterns.contains(.equatableReflexive))
    #expect(!patterns.contains(.comparableTrichotomy))
    #expect(!patterns.contains(.comparableMinMax))
    #expect(!patterns.contains(.additiveZeroIdentity))
    #expect(!patterns.contains(.strideableZeroIdentity))

    let plan = generator.plannedTest(
      for: type("Scalar", conformances: ["FloatingPoint"]),
      pattern: .floatingPointNaN
    )
    #expect(plan.parameters.map(\.name) == ["value"])
    #expect(plan.bodyStatements.count == 4)

    let code = generator.generateTest(
      for: type("Scalar", conformances: ["FloatingPoint"]),
      pattern: .floatingPointNaN
    )
    #expect(code.contains("let nan = Scalar.nan"))
    #expect(code.contains("nan != nan"))
  }

  @Test("Conditional recipes require their semantic prerequisites")
  func conditionalRecipePrerequisites() {
    let rawOnly = generator.detectPatterns(
      for: type(
        "Token",
        conformances: ["RawRepresentable"]
      )
    )
    let rawAndEquality = generator.detectPatterns(
      for: type(
        "Token",
        conformances: ["RawRepresentable", "Equatable"]
      )
    )
    let codableOnly = generator.detectPatterns(
      for: type(
        "Record",
        conformances: ["Codable"]
      )
    )
    let codableAndHashable = generator.detectPatterns(
      for: type(
        "Record",
        conformances: ["Codable", "Hashable"]
      )
    )

    #expect(!rawOnly.contains(.rawRepresentableRoundtrip))
    #expect(rawAndEquality.contains(.rawRepresentableRoundtrip))
    #expect(!codableOnly.contains(.codableRoundtrip))
    #expect(!codableAndHashable.contains(.codableRoundtrip))
  }

  @Test("CaseIterable recipe uses an existing generator and equality")
  func caseIterablePrerequisites() {
    let withoutEquality = generator.detectPatterns(
      for: type(
        "Phase",
        conformances: ["CaseIterable"]
      )
    )
    let withEquality = generator.detectPatterns(
      for: type(
        "Phase",
        conformances: ["CaseIterable", "Equatable"]
      )
    )

    #expect(!withoutEquality.contains(.caseIterableContainsValue))
    #expect(withEquality.contains(.caseIterableContainsValue))
  }

  @Test("Unspecialized generic declarations do not emit tests or generators")
  func genericDeclarationsAreRejected() {
    let generic = type(
      "Box",
      conformances: ["Equatable", "Collection"],
      properties: [property("value", "Int")],
      genericParameters: ["Element"]
    )

    #expect(generator.detectPatterns(for: generic).isEmpty)
    #expect(!generator.canAutoGenerateArbitrary(for: generic))
  }

  @Test("Automatic generators require a concrete fully generatable struct")
  func automaticGeneratorShape() {
    let complete = type(
      "Account",
      properties: [property("id", "Int"), property("name", "String")]
    )
    let partial = type(
      "Account",
      properties: [property("id", "Int"), property("client", "APIClient")]
    )
    let inaccessible = type(
      "Account",
      properties: [property("id", "Int", accessLevel: .private)]
    )
    let enumType = type(
      "Account",
      kind: "enum",
      properties: [property("id", "Int")]
    )

    #expect(generator.canAutoGenerateArbitrary(for: complete))
    #expect(generator.canFullyGenerateArbitrary(for: complete))
    #expect(!generator.canAutoGenerateArbitrary(for: partial))
    #expect(!generator.canAutoGenerateArbitrary(for: inaccessible))
    #expect(!generator.canAutoGenerateArbitrary(for: enumType))
  }

  @Test("Generated files import the resolved consumer module only")
  func consumerModuleImport() {
    let subject = type(
      "Point",
      conformances: ["Equatable"],
      properties: [property("x", "Int")]
    )
    let custom = generator.generateTestFile(
      types: [subject],
      sourceFile: "Point.swift",
      consumerModule: "Geometry"
    )
    let omitted = generator.generateTestFile(
      types: [subject],
      sourceFile: "Point.swift",
      consumerModule: nil
    )

    #expect(custom.contains("@testable import Geometry"))
    #expect(!custom.contains("@testable import InvariantSwift"))
    #expect(!omitted.contains("@testable import Geometry"))
    #expect(!omitted.contains("@testable import InvariantSwift"))
  }

  @Test("Generated value constructors use the runtime generator API")
  func runtimeGeneratorAPI() {
    let subject = type(
      "DiffFormat",
      properties: [
        property("old", "String"),
        property("new", "String"),
        property("separator", "String"),
      ]
    )
    let code = generator.generateArbitraryExtension(for: subject)

    #expect(code.contains("InvariantSwiftCore.Generatable"))
    #expect(code.contains("String.arbitrary.flatMap"))
    #expect(code.contains("String.arbitrary.map"))
    #expect(!code.contains("Gen.compose"))
    #expect(!code.contains("composer"))

    switch generator.generatorResult(for: "[Int]?") {
    case .success(let expression):
      #expect(expression == "OptionalGen.optional(valueGen: Gen<[Int]>.array(Int.arbitrary))")

    case .todoRequired:
      Issue.record("Expected a nested optional-array generator")
    }

    switch generator.generatorResult(for: "Set<Int>") {
    case .success(let expression):
      #expect(expression == "Gen<Set<Int>>.set(Int.arbitrary)")

    case .todoRequired:
      Issue.record("Expected a set generator")
    }

  }

  @Test("Every executable pattern has catalog metadata and a complete plan")
  func executablePatternCoverage() {
    let catalogPatterns = Set(
      ProtocolLawCatalog.all
        .flatMap(\.laws)
        .compactMap(\.patternIdentifier?.rawValue)
    )
    let subject = type("Subject", conformances: [])
    let executablePatterns = GhostwriterTestPattern.allCases.filter {
      catalogPatterns.contains($0.rawValue)
    }
    let plans = executablePatterns.map {
      generator.plannedTest(for: subject, pattern: $0)
    }

    #expect(Set(executablePatterns.map(\.rawValue)) == catalogPatterns)
    #expect(Set(plans.map(\.functionName)).count == executablePatterns.count)
    #expect(plans.allSatisfy { !$0.bodyStatements.isEmpty })
  }

  @Test("Multi-input algebra recipes preserve the required proof shape")
  func algebraRecipeShape() {
    let subject = type("Number", conformances: ["FixedWidthInteger"])
    let modular = generator.plannedTest(
      for: subject,
      pattern: .fixedWidthModularArithmetic
    )
    let setAlgebra = generator.plannedTest(
      for: subject,
      pattern: .setAlgebraIdempotence
    )
    let bitwise = generator.generateTest(
      for: subject,
      pattern: .binaryIntegerBitwiseIdentity
    )

    #expect(modular.parameters.map(\.name) == ["a", "b", "c"])
    #expect(modular.bodyStatements.count >= 10)
    #expect(setAlgebra.parameters.map(\.name) == ["a", "b", "c"])
    #expect(setAlgebra.bodyStatements.count == 10)
    #expect(bitwise.contains("let complement = ~value"))
    #expect(bitwise.contains("let restored = ~complement"))
  }

  private func type(
    _ name: String,
    kind: String = "struct",
    conformances: [String] = [],
    properties: [ExtractedProperty] = [],
    genericParameters: [String] = []
  ) -> ExtractedTypeInfo {
    ExtractedTypeInfo(
      name: name,
      kind: kind,
      sourceFile: "\(name).swift",
      line: 1,
      conformances: conformances,
      hasArbitraryAttribute: false,
      properties: properties,
      methods: [],
      genericParameters: genericParameters,
      accessLevel: .internal
    )
  }

  private func property(
    _ name: String,
    _ typeName: String,
    accessLevel: AccessLevel = .internal
  ) -> ExtractedProperty {
    ExtractedProperty(
      name: name,
      typeName: typeName,
      isOptional: false,
      isMutable: false,
      hasDefaultValue: false,
      accessLevel: accessLevel
    )
  }
}
