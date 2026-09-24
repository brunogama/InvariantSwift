import Foundation
import Testing

@testable import GhostwriterLib

@Suite("Ghostwriter additional laws")
struct GhostwriterAdditionalLawTests {
  private let generator = TestCodeGenerator()

  @Test("Additional laws render their operation and precondition")
  func lawRendering() {
    let subject = type("Flags", conformances: ["OptionSet"])
    let subset = generator.generateTest(for: subject, pattern: .setAlgebraSubsetDisjoint)
    let xor = generator.generateTest(for: subject, pattern: .optionSetSymmetricDifferenceBits)
    let overflow = generator.generateTest(for: subject, pattern: .fixedWidthOverflow)
    let sequence = generator.generateTest(for: subject, pattern: .sequenceUnderestimatedCount)

    #expect(subset.contains("isSubset(of: b)"))
    #expect(subset.contains("isDisjoint(with: b)"))
    #expect(xor.contains("a.rawValue ^ b.rawValue"))
    #expect(overflow.contains("if !reported.overflow"))
    #expect(sequence.contains("Array(value).count"))
  }

  @Test("Additional law bodies type-check against concrete Swift conformers")
  func lawBodiesTypeCheck() {
    let flags = type("Flags", conformances: ["OptionSet"])
    let integer = type("Int", conformances: ["FixedWidthInteger"])
    let recipes: [(ExtractedTypeInfo, GhostwriterTestPattern)] = [
      (flags, .setAlgebraAbsorption),
      (flags, .setAlgebraDistributivity),
      (flags, .setAlgebraSubsetDisjoint),
      (flags, .setAlgebraSymmetricDifference),
      (flags, .optionSetSymmetricDifferenceBits),
      (integer, .binaryIntegerDeMorgan),
      (integer, .fixedWidthOverflow),
      (integer, .fixedWidthEndianRoundtrip),
      (integer, .comparableMinMax),
    ]
    let snippets = recipes.map { subject, pattern in
      let rendered = generator.generateTest(for: subject, pattern: pattern)
      return
        rendered
        .replacingOccurrences(of: "@PropertyTest", with: "")
        .replacingOccurrences(of: "#expect", with: "assert")
    }
    let source = """
      struct Flags: OptionSet {
        let rawValue: Int
        init(rawValue: Int) { self.rawValue = rawValue }
      }

      \(snippets.joined(separator: "\n\n"))
      """
    let result = CompileVerifier().verify(code: source, fileName: "AdditionalLaws.swift")

    #expect(result.success, Comment(rawValue: result.output))
  }

  private func type(_ name: String, conformances: [String]) -> ExtractedTypeInfo {
    ExtractedTypeInfo(
      name: name,
      kind: "struct",
      sourceFile: "\(name).swift",
      line: 1,
      conformances: conformances,
      hasArbitraryAttribute: false,
      properties: [],
      methods: [],
      genericParameters: [],
      accessLevel: .internal
    )
  }
}
