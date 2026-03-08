// MARK: - Test Pattern Planning
// Extension for planning individual Ghostwriter test patterns.

import InvariantSwiftExpansionSupport

extension TestCodeGenerator {
  public func generateTest(
    for type: ExtractedTypeInfo,
    pattern: GhostwriterTestPattern
  ) -> String {
    GhostwriterExpansionRenderer.render(test: plannedTest(for: type, pattern: pattern))
  }

  func plannedTest(
    for type: ExtractedTypeInfo,
    pattern: GhostwriterTestPattern
  ) -> GhostwriterGeneratedTest {
    let typeName = type.name

    switch pattern {
    case .codableRoundtrip:
      return codableRoundtripTest(typeName: typeName)

    case .equatableReflexive:
      return equatableReflexiveTest(typeName: typeName)

    case .equatableSymmetric:
      return equatableSymmetricTest(typeName: typeName)

    case .equatableTransitive:
      return equatableTransitiveTest(typeName: typeName)

    case .hashableConsistency:
      return hashableConsistencyTest(typeName: typeName)

    case .comparableIrreflexive:
      return comparableIrreflexiveTest(typeName: typeName)

    case .comparableAsymmetric:
      return comparableAsymmetricTest(typeName: typeName)

    case .comparableTransitive:
      return comparableTransitiveTest(typeName: typeName)

    case .comparableTrichotomy:
      return comparableTrichotomyTest(typeName: typeName)
    }
  }

  private func codableRoundtripTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Codable roundtrip: encoding and decoding preserves value.",
      functionName: "test\(typeName)_codableRoundtrip",
      parameters: [ExpansionParameter(name: "value", type: typeName)],
      isThrowing: true,
      bodyStatements: [
        .letBinding(
          name: "encoded",
          initializer: ExpansionExpr.call("JSONEncoder")
            .method("encode", arguments: [.unlabeled(.variable("value"))])
            .trying()
        ),
        .letBinding(
          name: "decoded",
          initializer: ExpansionExpr.call("JSONDecoder")
            .method(
              "decode",
              arguments: [
                .unlabeled(.property("self", on: typeName)),
                .labeled("from", .variable("encoded")),
              ]
            )
            .trying()
        ),
        .expect(
          condition: .operation(.variable("decoded"), "==", .variable("value")),
          message: "Codable roundtrip should preserve value"
        ),
      ]
    )
  }

  private func equatableReflexiveTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Equatable reflexivity: x == x for all x.",
      functionName: "test\(typeName)_equatableReflexive",
      parameters: [ExpansionParameter(name: "value", type: typeName)],
      bodyStatements: [
        .expect(
          condition: .operation(.variable("value"), "==", .variable("value")),
          message: "Reflexivity: x == x"
        )
      ]
    )
  }

  private func equatableSymmetricTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Equatable symmetry: x == y implies y == x.",
      functionName: "test\(typeName)_equatableSymmetric",
      parameters: [
        ExpansionParameter(name: "a", type: typeName),
        ExpansionParameter(name: "b", type: typeName),
      ],
      bodyStatements: [
        .ifStatement(
          condition: .operation(.variable("a"), "==", .variable("b")),
          body: [
            .expect(
              condition: .operation(.variable("b"), "==", .variable("a")),
              message: "Symmetry: a == b implies b == a"
            )
          ]
        )
      ]
    )
  }

  private func equatableTransitiveTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Equatable transitivity: x == y && y == z implies x == z.",
      functionName: "test\(typeName)_equatableTransitive",
      parameters: [
        ExpansionParameter(name: "a", type: typeName),
        ExpansionParameter(name: "b", type: typeName),
        ExpansionParameter(name: "c", type: typeName),
      ],
      bodyStatements: [
        .ifStatement(
          condition: .operation(
            .operation(.variable("a"), "==", .variable("b")),
            "&&",
            .operation(.variable("b"), "==", .variable("c"))
          ),
          body: [
            .expect(
              condition: .operation(.variable("a"), "==", .variable("c")),
              message: "Transitivity: a == b && b == c implies a == c"
            )
          ]
        )
      ]
    )
  }

  private func hashableConsistencyTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Hashable consistency: equal values must have equal hash values.",
      functionName: "test\(typeName)_hashableConsistency",
      parameters: [
        ExpansionParameter(name: "a", type: typeName),
        ExpansionParameter(name: "b", type: typeName),
      ],
      bodyStatements: [
        .ifStatement(
          condition: .operation(.variable("a"), "==", .variable("b")),
          body: [
            .expect(
              condition: .operation(
                .property("hashValue", on: .variable("a")),
                "==",
                .property("hashValue", on: .variable("b"))
              ),
              message: "Equal values must have equal hash values"
            )
          ]
        )
      ]
    )
  }

  private func comparableIrreflexiveTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Comparable irreflexivity: !(x < x) for all x.",
      functionName: "test\(typeName)_comparableIrreflexive",
      parameters: [ExpansionParameter(name: "value", type: typeName)],
      bodyStatements: [
        .expect(
          condition: .prefix(
            op: "!",
            expression: .operation(.variable("value"), "<", .variable("value"))
          ),
          message: "Irreflexivity: !(x < x)"
        )
      ]
    )
  }

  private func comparableAsymmetricTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Comparable asymmetry: x < y implies !(y < x).",
      functionName: "test\(typeName)_comparableAsymmetric",
      parameters: [
        ExpansionParameter(name: "a", type: typeName),
        ExpansionParameter(name: "b", type: typeName),
      ],
      bodyStatements: [
        .ifStatement(
          condition: .operation(.variable("a"), "<", .variable("b")),
          body: [
            .expect(
              condition: .prefix(
                op: "!",
                expression: .operation(.variable("b"), "<", .variable("a"))
              ),
              message: "Asymmetry: a < b implies !(b < a)"
            )
          ]
        )
      ]
    )
  }

  private func comparableTransitiveTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Comparable transitivity: x < y && y < z implies x < z.",
      functionName: "test\(typeName)_comparableTransitive",
      parameters: [
        ExpansionParameter(name: "a", type: typeName),
        ExpansionParameter(name: "b", type: typeName),
        ExpansionParameter(name: "c", type: typeName),
      ],
      bodyStatements: [
        .ifStatement(
          condition: .operation(
            .operation(.variable("a"), "<", .variable("b")),
            "&&",
            .operation(.variable("b"), "<", .variable("c"))
          ),
          body: [
            .expect(
              condition: .operation(.variable("a"), "<", .variable("c")),
              message: "Transitivity: a < b && b < c implies a < c"
            )
          ]
        )
      ]
    )
  }

  private func comparableTrichotomyTest(typeName: String) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: "Comparable trichotomy: exactly one of <, ==, > holds.",
      functionName: "test\(typeName)_comparableTrichotomy",
      parameters: [
        ExpansionParameter(name: "a", type: typeName),
        ExpansionParameter(name: "b", type: typeName),
      ],
      bodyStatements: [
        .letBinding(
          name: "isLess",
          initializer: .operation(.variable("a"), "<", .variable("b"))
        ),
        .letBinding(
          name: "isEqual",
          initializer: .operation(.variable("a"), "==", .variable("b"))
        ),
        .letBinding(
          name: "isGreater",
          initializer: .operation(.variable("b"), "<", .variable("a"))
        ),
        .letBinding(
          name: "exactlyOne",
          initializer: .exactlyOneTrue([
            .variable("isLess"),
            .variable("isEqual"),
            .variable("isGreater"),
          ])
        ),
        .expect(
          condition: .variable("exactlyOne"),
          message: "Trichotomy: exactly one of <, ==, > holds"
        ),
      ]
    )
  }
}
