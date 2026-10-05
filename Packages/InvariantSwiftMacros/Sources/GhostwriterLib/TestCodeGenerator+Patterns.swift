// MARK: - Test Pattern Detection and Planning

import InvariantSwiftExpansionSupport

private enum ProtocolInheritance {
  static let parents: [String: [String]] = [
    "BidirectionalCollection": ["Collection"],
    "BinaryFloatingPoint": ["FloatingPoint"],
    "BinaryInteger": ["Comparable", "Hashable", "Numeric", "Strideable"],
    "Codable": ["Decodable", "Encodable"],
    "Collection": ["Sequence"],
    "Comparable": ["Equatable"],
    "FixedWidthInteger": ["BinaryInteger", "LosslessStringConvertible"],
    "FloatingPoint": ["Comparable", "Hashable", "SignedNumeric", "Strideable"],
    "Hashable": ["Equatable"],
    "MutableCollection": ["Collection"],
    "Numeric": ["AdditiveArithmetic"],
    "OptionSet": ["RawRepresentable", "SetAlgebra"],
    "RandomAccessCollection": ["BidirectionalCollection"],
    "RangeReplaceableCollection": ["Collection"],
    "SetAlgebra": ["Equatable"],
    "SignedInteger": ["BinaryInteger", "SignedNumeric"],
    "SignedNumeric": ["Numeric"],
    "UnsignedInteger": ["BinaryInteger"],
  ]

  static func closure(of declared: [String]) -> Set<String> {
    var resolved = Set(declared)
    var pending = declared.sorted()

    while let conformance = pending.popLast() {
      for parent in parents[conformance, default: []] where resolved.insert(parent).inserted {
        pending.append(parent)
      }
    }

    return resolved
  }
}

extension TestCodeGenerator {
  /// Returns whether a named type has a built-in `Generatable` conformance.
  public func isKnownGeneratableType(_ name: String) -> Bool {
    Self.knownGeneratableTypes.contains(name)
  }

  /// Detects executable catalog patterns, including inherited protocol laws.
  public func detectPatterns(for type: ExtractedTypeInfo) -> [GhostwriterTestPattern] {
    guard type.genericParameters.isEmpty else { return [] }

    var conformances = ProtocolInheritance.closure(of: type.conformances)
    if type.kind == "enum" && !type.enumCases.isEmpty {
      conformances.insert("Equatable")
    }
    var patterns = Set(conformances.flatMap(patterns(forConformance:)))

    if conformances.contains("FloatingPoint") {
      patterns.remove(.equatableReflexive)
      patterns.remove(.comparableTrichotomy)
      patterns.remove(.comparableMinMax)
      patterns.remove(.additiveZeroIdentity)
    }

    return
      patterns
      .filter { isEligible($0, conformances: conformances) }
      .sorted { $0.rawValue < $1.rawValue }
  }

  private func patterns(forConformance name: String) -> [GhostwriterTestPattern] {
    ProtocolLawCatalog.entries(forConformance: name).flatMap { entry in
      entry.laws.compactMap { law in
        law.patternIdentifier.flatMap {
          GhostwriterTestPattern(rawValue: $0.rawValue)
        }
      }
    }
  }

  private func isEligible(
    _ pattern: GhostwriterTestPattern,
    conformances: Set<String>
  ) -> Bool {
    switch pattern {
    case .codableRoundtrip:
      return conformances.isSuperset(of: ["Decodable", "Encodable", "Equatable"])

    case .losslessStringRoundtrip, .rawRepresentableRoundtrip:
      return conformances.contains("Equatable")

    case .caseIterableContainsValue:
      return conformances.contains("Equatable")

    case .strideableZeroIdentity:
      return conformances.contains("Equatable") && !conformances.contains("FloatingPoint")

    default:
      return true
    }
  }
}

struct PatternDefinition: Sendable {
  let docComment: String
  let parameterNames: [String]
  let isThrowing: Bool
  let statements: @Sendable (String) -> [ExpansionStatement]

  func test(
    identity: GeneratedTypeIdentity,
    pattern: GhostwriterTestPattern
  ) -> GhostwriterGeneratedTest {
    GhostwriterGeneratedTest(
      docComment: docComment,
      functionName: "test\(identity.functionNameComponent)_\(pattern.rawValue)",
      parameters: parameterNames.map {
        ExpansionParameter(name: $0, type: identity.reference)
      },
      isThrowing: isThrowing,
      bodyStatements: statements(identity.reference)
    )
  }
}

extension PatternDefinition {
  static func expectation(
    _ docComment: String,
    parameters: [String],
    message: String,
    condition: @escaping @Sendable (String) -> ExpansionExpr
  ) -> Self {
    body(docComment, parameters: parameters) { typeName in
      [.expect(condition: condition(typeName), message: message)]
    }
  }

  static func body(
    _ docComment: String,
    parameters: [String],
    isThrowing: Bool = false,
    statements: @escaping @Sendable (String) -> [ExpansionStatement]
  ) -> Self {
    Self(
      docComment: docComment,
      parameterNames: parameters,
      isThrowing: isThrowing,
      statements: statements
    )
  }
}

enum PatternDefinitions {
  static let all: [GhostwriterTestPattern: PatternDefinition] = [
    .codableRoundtrip: codableRoundtrip,
    .equatableReflexive: .expectation(
      "Equatable reflexivity: x == x for all non-NaN x.",
      parameters: ["value"],
      message: "Reflexivity: x == x"
    ) { _ in binary(id("value"), "==", id("value")) },
    .equatableSymmetric: .body(
      "Equatable symmetry: equality agrees in both directions.",
      parameters: ["a", "b"]
    ) { _ in
      [
        binding("forward", binary(id("a"), "==", id("b"))),
        binding("reverse", binary(id("b"), "==", id("a"))),
        expect(binary(id("forward"), "==", id("reverse")), "Equality must be symmetric"),
      ]
    },
    .equatableTransitive: .body(
      "Equatable transitivity: x == y and y == z implies x == z.",
      parameters: ["a", "b", "c"]
    ) { _ in
      implication(
        binary(binary(id("a"), "==", id("b")), "&&", binary(id("b"), "==", id("c"))),
        binary(id("a"), "==", id("c")),
        "Transitivity: a == b and b == c implies a == c"
      )
    },
    .equatableNegation: .body(
      "Equatable negation: != is the negation of ==.",
      parameters: ["a", "b"]
    ) { _ in
      [
        binding("isUnequal", binary(id("a"), "!=", id("b"))),
        binding("isEqual", binary(id("a"), "==", id("b"))),
        expect(binary(id("isUnequal"), "==", not(id("isEqual"))), "!= must negate =="),
      ]
    },
    .hashableConsistency: .body(
      "Hashable consistency: an equal copy keeps its hash within this process.",
      parameters: ["a"]
    ) { _ in
      [
        binding("b", id("a")),
        expect(binary(id("a"), "==", id("b")), "A copied value must stay equal"),
        expect(
          binary(member("a", "hashValue"), "==", member("b", "hashValue")),
          "Equal copies must have equal hash values"
        ),
      ]
    },
    .comparableIrreflexive: .expectation(
      "Comparable irreflexivity: !(x < x).",
      parameters: ["value"],
      message: "Irreflexivity: !(x < x)"
    ) { _ in not(binary(id("value"), "<", id("value"))) },
    .comparableAsymmetric: .body(
      "Comparable asymmetry: x < y implies !(y < x).",
      parameters: ["a", "b"]
    ) { _ in
      implication(
        binary(id("a"), "<", id("b")),
        not(binary(id("b"), "<", id("a"))),
        "Asymmetry: a < b implies !(b < a)"
      )
    },
    .comparableTransitive: .body(
      "Comparable transitivity: x < y and y < z implies x < z.",
      parameters: ["a", "b", "c"]
    ) { _ in
      implication(
        binary(binary(id("a"), "<", id("b")), "&&", binary(id("b"), "<", id("c"))),
        binary(id("a"), "<", id("c")),
        "Transitivity: a < b and b < c implies a < c"
      )
    },
    .comparableTrichotomy: comparableTrichotomy,
    .comparableDerivedOperators: comparableDerivedOperators,
    .comparableMinMax: comparableMinMax,
    .additiveZeroIdentity: .body(
      "AdditiveArithmetic zero is an additive identity.",
      parameters: ["value"]
    ) { typeName in
      [
        binding("sum", binary(id("value"), "+", member(typeName, "zero"))),
        expect(binary(id("sum"), "==", id("value")), "Adding zero must preserve a value"),
      ]
    },
    .losslessStringRoundtrip: losslessStringRoundtrip,
    .rawRepresentableRoundtrip: rawRepresentableRoundtrip,
    .sequenceUnderestimatedCount: sequenceUnderestimatedCount,
    .collectionCountDistance: collectionCountDistance,
    .collectionEmptyBounds: collectionEmptyBounds,
    .collectionIndicesCount: collectionIndicesCount,
    .bidirectionalIndexRoundtrip: bidirectionalIndexRoundtrip,
    .setAlgebraIdempotence: setAlgebraIdempotence,
    .setAlgebraUnionIdentity: setAlgebraUnionIdentity,
    .setAlgebraAbsorption: setAlgebraAbsorption,
    .setAlgebraDistributivity: setAlgebraDistributivity,
    .setAlgebraSubsetDisjoint: setAlgebraSubsetDisjoint,
    .setAlgebraSymmetricDifference: setAlgebraSymmetricDifference,
    .binaryIntegerBitwiseIdentity: binaryIntegerBitwiseIdentity,
    .binaryIntegerDeMorgan: binaryIntegerDeMorgan,
    .fixedWidthByteSwap: .expectation(
      "Byte swapping twice preserves a fixed-width integer.",
      parameters: ["value"],
      message: "byteSwapped must be an involution"
    ) { _ in
      binary(member(member(id("value"), "byteSwapped"), "byteSwapped"), "==", id("value"))
    },
    .fixedWidthModularArithmetic: fixedWidthModularArithmetic,
    .fixedWidthOverflow: fixedWidthOverflow,
    .fixedWidthEndianRoundtrip: fixedWidthEndianRoundtrip,
    .floatingPointNaN: floatingPointNaN,
    .caseIterableContainsValue: caseIterableContainsValue,
    .caseIterableStableCount: caseIterableStableCount,
    .strideableZeroIdentity: strideableZeroIdentity,
    .optionSetBitwiseOperations: optionSetBitwiseOperations,
    .optionSetSymmetricDifferenceBits: optionSetSymmetricDifferenceBits,
    .optionSetMembershipMutation: optionSetMembershipMutation,
    .randomAccessDistanceAntisymmetry: randomAccessDistanceAntisymmetry,
  ]
}

extension TestCodeGenerator {
  /// Renders one executable protocol-law test.
  public func generateTest(
    for type: ExtractedTypeInfo,
    pattern: GhostwriterTestPattern
  ) -> String {
    GhostwriterExpansionRenderer.render(test: plannedTest(for: type, pattern: pattern))
  }

  func plannedTest(
    for type: ExtractedTypeInfo,
    pattern: GhostwriterTestPattern,
    identity: GeneratedTypeIdentity? = nil
  ) -> GhostwriterGeneratedTest {
    guard let definition = PatternDefinitions.all[pattern] else {
      preconditionFailure("Missing definition for \(pattern.rawValue)")
    }
    return definition.test(
      identity: identity ?? GeneratedTypeIdentity(type: type),
      pattern: pattern
    )
  }
}

func id(_ name: String) -> ExpansionExpr {
  .variable(name)
}

func member(_ base: String, _ name: String) -> ExpansionExpr {
  .property(name, on: base)
}

func member(_ base: ExpansionExpr, _ name: String) -> ExpansionExpr {
  .property(name, on: base)
}

func call(
  _ name: String,
  _ arguments: [ExpansionArgument] = []
) -> ExpansionExpr {
  .call(name, arguments: arguments)
}

func binary(
  _ lhs: ExpansionExpr,
  _ op: String,
  _ rhs: ExpansionExpr
) -> ExpansionExpr {
  .operation(lhs, op, rhs)
}

func not(_ expression: ExpansionExpr) -> ExpansionExpr {
  .prefix(op: "!", expression: expression)
}

func binding(_ name: String, _ expression: ExpansionExpr) -> ExpansionStatement {
  .letBinding(name: name, initializer: expression)
}

func expect(_ condition: ExpansionExpr, _ message: String) -> ExpansionStatement {
  .expect(condition: condition, message: message)
}

func implication(
  _ condition: ExpansionExpr,
  _ consequence: ExpansionExpr,
  _ message: String
) -> [ExpansionStatement] {
  [.ifStatement(condition: condition, body: [expect(consequence, message)])]
}
