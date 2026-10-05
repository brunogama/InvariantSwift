import Testing
@testable import GhostwriterLib

@Suite("Ghostwriter generator eligibility")
struct GhostwriterEligibilityTests {
  @Test("Unsupported properties do not produce an incomplete generator")
  func unsupportedProperty() {
    let type = ExtractedTypeInfo(
      name: "DictionaryBacked",
      kind: "struct",
      sourceFile: "DictionaryBacked.swift",
      line: 1,
      conformances: ["Equatable", "Sendable"],
      hasArbitraryAttribute: false,
      properties: [
        ExtractedProperty(
          name: "values",
          typeName: "[String: Int]",
          isOptional: false,
          isMutable: false,
          hasDefaultValue: false,
          accessLevel: .public
        )
      ],
      methods: [],
      genericParameters: [],
      accessLevel: .public
    )

    #expect(GhostwriterCore.canAutoGenerateArbitrary(for: type))
    #expect(GhostwriterCore.isPropertyTypeGeneratable("[String: Int]"))
    #expect(!GhostwriterCore.isPropertyTypeGeneratable("[APIClient: Int]"))
    #expect(!GhostwriterCore.isKnownGeneratableType("Date"))
  }

  @Test("Generated memberwise arguments exclude declarations without constructor parameters")
  func memberwiseArguments() throws {
    let analysis = SwiftSyntaxTypeExtractor().analyze(
      source: """
        struct Record {
          static let kind: Int = 1
          let version: Int = 1
          lazy var cache: Int = 0
          let value: Int
        }

        struct Explicit {
          let value: Int
          init(value: Int) { self.value = value }
        }

        struct Incompatible {
          let value: Int
          private init(value: Int) { self.value = value }
        }

        public struct PublicValue: Equatable {
          public let value: Int
        }

        public struct PublicSendableValue: Equatable, Sendable {
          public let value: Int
        }
        """,
      filePath: "Record.swift"
    )
    let record = try #require(analysis.types.first { $0.name == "Record" })
    let explicit = try #require(analysis.types.first { $0.name == "Explicit" })
    let incompatible = try #require(analysis.types.first { $0.name == "Incompatible" })
    let publicValue = try #require(analysis.types.first { $0.name == "PublicValue" })
    let publicSendable = try #require(
      analysis.types.first { $0.name == "PublicSendableValue" }
    )

    #expect(record.properties.map(\.name) == ["value"])
    #expect(TestCodeGenerator().canFullyGenerateArbitrary(for: record))
    #expect(TestCodeGenerator().canFullyGenerateArbitrary(for: explicit))
    #expect(!TestCodeGenerator().canFullyGenerateArbitrary(for: incompatible))
    #expect(!TestCodeGenerator().canFullyGenerateArbitrary(for: publicValue))
    #expect(TestCodeGenerator().canFullyGenerateArbitrary(for: publicSendable))
  }
}
