import Foundation
import InvariantSwiftExpansionSupport
import Testing

@testable import GhostwriterLib

@Suite("Ghostwriter LawForge candidates")
struct GhostwriterLawForgeCandidateTests {
  private let extractor = SwiftSyntaxTypeExtractor()
  private let generator = TestCodeGenerator()

  @Test("LawForge subcommand selects Swift candidate generation")
  func subcommandSelection() {
    let selected = GhostwriterCore.parseArguments([
      "GhostwriterCLI", "lawforge", "--source", "Mark.swift",
    ])
    let standard = GhostwriterCore.parseArguments([
      "GhostwriterCLI", "--source", "Mark.swift",
    ])

    #expect(selected.discoverLaws)
    #expect(selected.sources == ["Mark.swift"])
    #expect(selected.outputDirectory == "Tests/LawForgeGenerated/")
    #expect(!standard.discoverLaws)
  }

  @Test("Normal generation combines candidate and catalog laws")
  func operationDiscovery() {
    let source = """
      struct Mark: Equatable {
        var value: Int
        func normalized() -> Self { self }
        func reversed() -> Self { self }
        func union(_ other: Self) -> Self { self }
        func encoded() -> String { String(value) }
        init(value: Int) { self.value = value }
        init(data: String) { self.value = Int(data) ?? 0 }
      }
      """
    let type = extractor.analyze(source: source, filePath: "Mark.swift").types[0]
    let candidates = generator.discoverLawCandidates(for: type)

    #expect(candidates.count == 5)
    #expect(
      Set(candidates.map(\.kind.rawValue)) == [
        "idempotent", "involution", "commutative", "associative", "roundtrip",
      ]
    )
    let combinedCount = generator.generatedTestCount(for: type)
    let candidateCount = generator.generatedTestCount(for: type, discoverLaws: true)
    #expect(candidateCount == candidates.count)
    #expect(combinedCount > candidateCount)

    let combinedCode = generator.generateTestFile(
      types: [type],
      sourceFile: "Mark.swift",
      consumerModule: nil
    )
    #expect(combinedCode.contains("test4_Mark_lawforge_normalized_idempotent"))
    #expect(combinedCode.contains("test4_Mark_equatableReflexive"))
    #expect(generatedTestCount(in: combinedCode) == combinedCount)

    let candidateCode = generator.generateTestFile(
      types: [type],
      sourceFile: "Mark.swift",
      consumerModule: nil,
      discoverLaws: true
    )
    #expect(candidateCode.contains("test4_Mark_lawforge_normalized_idempotent"))
    #expect(candidateCode.contains("test4_Mark_lawforge_encoded_roundtrip"))
    #expect(!candidateCode.contains("test4_Mark_equatableReflexive"))
    #expect(generatedTestCount(in: candidateCode) == candidateCount)
    #expect(candidateCode.contains("Regenerate with: swift package ghostwrite lawforge"))
  }

  @Test("Candidate law bodies type-check against the extracted type")
  func candidateBodiesTypeCheck() {
    let source = """
      struct Mark: Equatable {
        var value: Int
        func normalized() -> Self { self }
        func reversed() -> Self { self }
        func union(_ other: Self) -> Self { self }
        func encoded() -> String { String(value) }
        init(value: Int) { self.value = value }
        init(data: String) { self.value = Int(data) ?? 0 }
      }
      """
    let type = extractor.analyze(source: source, filePath: "Mark.swift").types[0]
    let snippets = generator.plannedCandidateTests(for: type).map {
      GhostwriterExpansionRenderer.render(test: $0)
        .replacingOccurrences(of: "@PropertyTest", with: "")
        .replacingOccurrences(of: "#expect", with: "assert")
    }
    let result = CompileVerifier().verify(
      code: source + "\n" + snippets.joined(separator: "\n"),
      fileName: "MarkCandidateTests.swift"
    )
    #expect(result.success, Comment(rawValue: result.output))
  }

  @Test("Speculative laws require equality and unambiguous signatures")
  func excludesUnsafeOperations() {
    let source = """
      struct NoEquality {
        func normalized() -> Self { self }
      }
      struct Overloaded: Equatable {
        var value: Int
        func normalized() -> Self { self }
        func normalized(_ count: Int) -> Self { self }
      }
      """
    let types = extractor.analyze(source: source, filePath: "Cases.swift").types
    #expect(generator.discoverLawCandidates(for: types[0]).isEmpty)
    #expect(generator.discoverLawCandidates(for: types[1]).isEmpty)
  }

  private func generatedTestCount(in code: String) -> Int {
    code.components(separatedBy: "@PropertyTest").count - 1
  }
}
