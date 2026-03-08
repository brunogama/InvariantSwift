// MARK: - Test Pattern Generation
// Extension for generating individual test patterns.

import Foundation
import MacroTemplateKit
import SwiftSyntax
import SwiftSyntaxBuilder

extension TestCodeGenerator {

  // MARK: - Individual Test Generation

  /// Generate a single test for a type and pattern.
  public func generateTest(
    for type: ExtractedTypeInfo,
    pattern: GhostwriterTestPattern
  ) -> String {
    let typeName = type.name

    switch pattern {
    case .codableRoundtrip:
      return generateCodableRoundtripTest(typeName: typeName)

    case .equatableReflexive:
      return generateEquatableReflexiveTest(typeName: typeName)

    case .equatableSymmetric:
      return generateEquatableSymmetricTest(typeName: typeName)

    case .equatableTransitive:
      return generateEquatableTransitiveTest(typeName: typeName)

    case .hashableConsistency:
      return generateHashableConsistencyTest(typeName: typeName)

    case .comparableIrreflexive:
      return generateComparableIrreflexiveTest(typeName: typeName)

    case .comparableAsymmetric:
      return generateComparableAsymmetricTest(typeName: typeName)

    case .comparableTransitive:
      return generateComparableTransitiveTest(typeName: typeName)

    case .comparableTrichotomy:
      return generateComparableTrichotomyTest(typeName: typeName)
    }
  }

  // MARK: - Pattern Generators

  private func generateCodableRoundtripTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Codable roundtrip: encoding and decoding preserves value.",
      functionName: "test\(typeName)_codableRoundtrip",
      parameters: [("value", typeName)],
      isThrowing: true,
      bodyStatements: [
        GhostwriterPatternRenderer.letBinding(
          name: "encoded",
          initializer: .call("JSONEncoder")
            .method("encode") { .unlabeled(.variable("value")) }
            .trying()
        ),
        GhostwriterPatternRenderer.letBinding(
          name: "decoded",
          initializer: .call("JSONDecoder")
            .method("decode") {
              TemplateArgument<Void>.unlabeled(.property("self", on: typeName))
              TemplateArgument<Void>.labeled("from", .variable("encoded"))
            }
            .trying()
        ),
        GhostwriterPatternRenderer.rawStatement(
          "#expect(decoded == value, \"Codable roundtrip should preserve value\")"
        ),
      ]
    )
  }

  private func generateEquatableReflexiveTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Equatable reflexivity: x == x for all x.",
      functionName: "test\(typeName)_equatableReflexive",
      parameters: [("value", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.rawStatement(
          "#expect(value == value, \"Reflexivity: x == x\")"
        )
      ]
    )
  }

  private func generateEquatableSymmetricTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Equatable symmetry: x == y implies y == x.",
      functionName: "test\(typeName)_equatableSymmetric",
      parameters: [("a", typeName), ("b", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.ifStatement(
          condition: .operation(.variable("a"), "==", .variable("b")),
          then: [
            GhostwriterPatternRenderer.rawStatement(
              "#expect(b == a, \"Symmetry: a == b implies b == a\")"
            )
          ]
        )
      ]
    )
  }

  private func generateEquatableTransitiveTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Equatable transitivity: x == y && y == z implies x == z.",
      functionName: "test\(typeName)_equatableTransitive",
      parameters: [("a", typeName), ("b", typeName), ("c", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.ifStatement(
          condition: .operation(
            .operation(.variable("a"), "==", .variable("b")),
            "&&",
            .operation(.variable("b"), "==", .variable("c"))
          ),
          then: [
            GhostwriterPatternRenderer.rawStatement(
              "#expect(a == c, \"Transitivity: a == b && b == c implies a == c\")"
            )
          ]
        )
      ]
    )
  }

  private func generateHashableConsistencyTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Hashable consistency: equal values must have equal hash values.",
      functionName: "test\(typeName)_hashableConsistency",
      parameters: [("a", typeName), ("b", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.ifStatement(
          condition: .operation(.variable("a"), "==", .variable("b")),
          then: [
            GhostwriterPatternRenderer.rawStatement(
              "#expect(a.hashValue == b.hashValue, \"Equal values must have equal hash values\")"
            )
          ]
        )
      ]
    )
  }

  private func generateComparableIrreflexiveTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Comparable irreflexivity: !(x < x) for all x.",
      functionName: "test\(typeName)_comparableIrreflexive",
      parameters: [("value", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.rawStatement(
          "#expect(!(value < value), \"Irreflexivity: !(x < x)\")"
        )
      ]
    )
  }

  private func generateComparableAsymmetricTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Comparable asymmetry: x < y implies !(y < x).",
      functionName: "test\(typeName)_comparableAsymmetric",
      parameters: [("a", typeName), ("b", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.ifStatement(
          condition: .operation(.variable("a"), "<", .variable("b")),
          then: [
            GhostwriterPatternRenderer.rawStatement(
              "#expect(!(b < a), \"Asymmetry: a < b implies !(b < a)\")"
            )
          ]
        )
      ]
    )
  }

  private func generateComparableTransitiveTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Comparable transitivity: x < y && y < z implies x < z.",
      functionName: "test\(typeName)_comparableTransitive",
      parameters: [("a", typeName), ("b", typeName), ("c", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.ifStatement(
          condition: .operation(
            .operation(.variable("a"), "<", .variable("b")),
            "&&",
            .operation(.variable("b"), "<", .variable("c"))
          ),
          then: [
            GhostwriterPatternRenderer.rawStatement(
              "#expect(a < c, \"Transitivity: a < b && b < c implies a < c\")"
            )
          ]
        )
      ]
    )
  }

  private func generateComparableTrichotomyTest(typeName: String) -> String {
    GhostwriterPatternRenderer.testFunction(
      docComment: "Comparable trichotomy: exactly one of <, ==, > holds.",
      functionName: "test\(typeName)_comparableTrichotomy",
      parameters: [("a", typeName), ("b", typeName)],
      bodyStatements: [
        GhostwriterPatternRenderer.letBinding(
          name: "isLess",
          initializer: .operation(.variable("a"), "<", .variable("b"))
        ),
        GhostwriterPatternRenderer.letBinding(
          name: "isEqual",
          initializer: .operation(.variable("a"), "==", .variable("b"))
        ),
        GhostwriterPatternRenderer.letBinding(
          name: "isGreater",
          initializer: .operation(.variable("b"), "<", .variable("a"))
        ),
        GhostwriterPatternRenderer.rawLetBinding(
          name: "exactlyOne",
          initializer: "[isLess, isEqual, isGreater].filter { $0 }.count == 1"
        ),
        GhostwriterPatternRenderer.rawStatement(
          "#expect(exactlyOne, \"Trichotomy: exactly one of <, ==, > holds\")"
        ),
      ]
    )
  }
}
