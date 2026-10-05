import Testing

@testable import GhostwriterLib

@Suite("Ghostwriter custom generators")
struct GhostwriterCustomGeneratorTests {
  private let generator = TestCodeGenerator()

  @Test("Nested dictionary fields use key and value generators")
  func dictionaryGenerator() {
    switch generator.generatorResult(for: "[String: [Int]]") {
    case .success(let expression):
      #expect(expression.contains("Gen<[String: [Int]]>.dictionary"))
      #expect(expression.contains("Gen<[Int]>.array(Int.arbitrary)"))

    case .todoRequired:
      Issue.record("Expected a nested dictionary generator")
    }
  }

  @Test("Finite enums use every case as a generated sample")
  func finiteEnumGenerator() throws {
    let analysis = SwiftSyntaxTypeExtractor().analyze(
      source: "enum Phase: CaseIterable, Equatable { case ready, running, done }",
      filePath: "Phase.swift"
    )
    let phase = try #require(analysis.types.first)
    let code = generator.generateTestFile(types: [phase], sourceFile: "Phase.swift")

    #expect(phase.enumCases == ["ready", "running", "done"])
    #expect(generator.canAutoGenerateArbitrary(for: phase))
    #expect(code.contains("Gen.oneOf"))
    #expect(code.contains("Gen.pure(Phase.ready)"))
    #expect(code.contains("test14_InvariantSwift_5_Phase_caseIterableContainsValue"))

    let payload = SwiftSyntaxTypeExtractor().analyze(
      source: "enum Message: Equatable { case text(String); case none }",
      filePath: "Message.swift"
    )
    #expect(payload.types.first?.enumCases.isEmpty == true)
    #expect(payload.types.first.map(generator.canAutoGenerateArbitrary(for:)) == false)
  }

  @Test("Writable scalar fields generate related samples for lens laws")
  func writableFieldLaws() throws {
    let analysis = SwiftSyntaxTypeExtractor().analyze(
      source: """
        struct Point: Equatable { var x: Int }
        struct Locked: Equatable { private(set) var value: Int }
        struct Observed: Equatable { var value: Int = 0 { didSet {} } }
        """,
      filePath: "Point.swift"
    )
    let point = try #require(analysis.types.first)
    let locked = try #require(analysis.types.first { $0.name == "Locked" })
    let observed = try #require(analysis.types.first { $0.name == "Observed" })
    let code = generator.generateTestFile(types: [point], sourceFile: "Point.swift")

    #expect(point.properties.first?.isMutable == true)
    #expect(locked.properties.first?.isMutable == false)
    #expect(observed.properties.isEmpty)
    #expect(code.contains("test14_InvariantSwift_5_Point_x_lensLaws(root: Point, value: Int"))
    #expect(code.contains("updated.x = value"))
    #expect(code.contains("twice.x = replacement"))
    #expect(!code.contains("testLocked_value_lensLaws"))
  }

  @Test("OptionSet mutations use generated set values as elements")
  func optionSetMutation() throws {
    let analysis = SwiftSyntaxTypeExtractor().analyze(
      source: """
        struct Flags: OptionSet, Sendable {
          let rawValue: Int
          init(rawValue: Int) { self.rawValue = rawValue }
        }
        """,
      filePath: "Flags.swift"
    )
    let flags = try #require(analysis.types.first)
    let code = generator.generateTestFile(types: [flags], sourceFile: "Flags.swift")

    #expect(generator.canAutoGenerateArbitrary(for: flags))
    #expect(
      code.contains(
        "test14_InvariantSwift_5_Flags_optionSetMembershipMutation(set: Flags, element: Flags)"
      )
    )
    #expect(code.contains("if !element.isEmpty"))
    #expect(code.contains("modified.insert(element)"))
    #expect(code.contains("modified.remove(element)"))
  }
}
