import InvariantSwiftExpansionSupport

/// A law inferred from operation names and signatures, pending runtime validation.
public struct LawForgeCandidate: Sendable {
  /// The algebraic relation suggested by an operation.
  public enum Kind: String, Sendable {
    case idempotent
    case involution
    case commutative
    case associative
    case roundtrip
  }

  /// The proposed algebraic relation.
  public let kind: Kind
  /// The operation under test.
  public let operation: String
  /// The initializer label paired with a round-trip operation, if any.
  public let inverse: String?

  init(kind: Kind, operation: String, inverse: String? = nil) {
    self.kind = kind
    self.operation = operation
    self.inverse = inverse
  }
}

extension TestCodeGenerator {
  /// Discovers LawForge-style candidates from concrete, accessible operations.
  public func discoverLawCandidates(for type: ExtractedTypeInfo) -> [LawForgeCandidate] {
    guard type.genericParameters.isEmpty,
      type.kind == "struct" || type.kind == "enum",
      detectPatterns(for: type).contains(.equatableReflexive)
    else { return [] }

    let methods = type.methods.filter {
      $0.accessLevel >= .internal && !$0.isStatic && !$0.isMutating
        && !$0.isThrowing && !$0.isAsync
    }
    let unique = methods.filter { method in
      methods.filter { $0.name == method.name }.count == 1
    }
    var candidates: [LawForgeCandidate] = []
    for method in unique {
      let name = method.name.lowercased()
      if isEndomorphism(method, of: type) {
        if Self.idempotentNames.contains(name) {
          candidates.append(.init(kind: .idempotent, operation: method.name))
        }
        if Self.involutionNames.contains(name) {
          candidates.append(.init(kind: .involution, operation: method.name))
        }
      }
      if isBinaryEndomorphism(method, of: type) {
        if Self.commutativeNames.contains(name) {
          candidates.append(.init(kind: .commutative, operation: method.name))
        }
        if Self.associativeNames.contains(name) {
          candidates.append(.init(kind: .associative, operation: method.name))
        }
      }
    }
    candidates += roundtripCandidates(methods: unique, type: type)
    return candidates.sorted {
      ($0.operation, $0.kind.rawValue) < ($1.operation, $1.kind.rawValue)
    }
  }

  func plannedCandidateTests(
    for type: ExtractedTypeInfo,
    identity: GeneratedTypeIdentity? = nil
  ) -> [GhostwriterGeneratedTest] {
    let identity = identity ?? GeneratedTypeIdentity(type: type)
    return discoverLawCandidates(for: type).map { candidate in
      let method = type.methods.first { $0.name == candidate.operation }
      let label = method?.parameters.first?.label
      let operation = candidate.operation
      let first = id("a").method(operation)
      switch candidate.kind {
      case .idempotent:
        return candidateTest(
          candidate,
          identity,
          ["a"],
          (first.method(operation), id("a").method(operation))
        )

      case .involution:
        return candidateTest(
          candidate,
          identity,
          ["a"],
          (first.method(operation), id("a"))
        )

      case .commutative:
        return candidateTest(
          candidate,
          identity,
          ["a", "b"],
          (
            apply(operation, label: label, to: id("a"), with: id("b")),
            apply(operation, label: label, to: id("b"), with: id("a"))
          )
        )

      case .associative:
        let left = apply(
          operation,
          label: label,
          to: apply(operation, label: label, to: id("a"), with: id("b")),
          with: id("c")
        )
        let right = apply(
          operation,
          label: label,
          to: id("a"),
          with: apply(operation, label: label, to: id("b"), with: id("c"))
        )
        return candidateTest(candidate, identity, ["a", "b", "c"], (left, right))

      case .roundtrip:
        let inverse = candidate.inverse ?? "init"
        let encoded = id("a").method(operation)
        let decoded = call(identity.reference, [.init(label: inverse, expression: encoded)])
        return candidateTest(candidate, identity, ["a"], (decoded, id("a")))
      }
    }
  }

  private func candidateTest(
    _ candidate: LawForgeCandidate,
    _ identity: GeneratedTypeIdentity,
    _ parameters: [String],
    _ expressions: (lhs: ExpansionExpr, rhs: ExpansionExpr)
  ) -> GhostwriterGeneratedTest {
    let suffix = "\(candidate.operation)_\(candidate.kind.rawValue)"
    return GhostwriterGeneratedTest(
      docComment: "Candidate \(candidate.kind.rawValue) law for \(candidate.operation).",
      functionName: "test\(identity.functionNameComponent)_lawforge_\(suffix)",
      parameters: parameters.map { .init(name: $0, type: identity.reference) },
      bodyStatements: [
        binding("lhs", expressions.lhs), binding("rhs", expressions.rhs),
        expect(binary(id("lhs"), "==", id("rhs")), "Candidate \(suffix) law failed"),
      ]
    )
  }

  private func apply(
    _ name: String,
    label: String?,
    to base: ExpansionExpr,
    with value: ExpansionExpr
  ) -> ExpansionExpr {
    base.method(name, arguments: [.init(label: label, expression: value)])
  }

  private func isEndomorphism(_ method: ExtractedMethod, of type: ExtractedTypeInfo) -> Bool {
    method.parameters.isEmpty
      && [type.name, type.sourceQualifiedName, "Self"].contains(method.returnType)
  }

  private func isBinaryEndomorphism(
    _ method: ExtractedMethod,
    of type: ExtractedTypeInfo
  ) -> Bool {
    method.parameters.count == 1
      && [type.name, type.sourceQualifiedName, "Self"].contains(method.parameters[0].typeName)
      && [type.name, type.sourceQualifiedName, "Self"].contains(method.returnType)
  }

  private func roundtripCandidates(
    methods: [ExtractedMethod],
    type: ExtractedTypeInfo
  ) -> [LawForgeCandidate] {
    let initializers = type.methods.filter {
      $0.name == "init" && $0.parameters.count == 1 && !$0.isThrowing
        && !$0.isAsync && $0.accessLevel >= .internal
    }
    return methods.compactMap { method in
      guard method.parameters.isEmpty,
        Self.forwardNames.contains(method.name.lowercased()),
        let output = method.returnType,
        let initializer = initializers.first(where: {
          $0.parameters[0].typeName == output && $0.parameters[0].label != nil
        })
      else { return nil }
      return .init(
        kind: .roundtrip,
        operation: method.name,
        inverse: initializer.parameters[0].label
      )
    }
  }

  private static let idempotentNames: Set<String> = [
    "normalized", "sorted", "canonicalized", "trimmed", "deduplicated",
    "lowercased", "uppercased", "standardized", "sanitized",
  ]
  private static let involutionNames: Set<String> = [
    "reversed", "inverted", "toggled", "flipped", "transposed", "complemented",
  ]
  private static let commutativeNames: Set<String> = [
    "union", "intersection", "combined", "sum", "maximum", "minimum",
  ]
  private static let associativeNames: Set<String> = [
    "union", "intersection", "combined", "concatenated", "composed",
  ]
  private static let forwardNames: Set<String> = [
    "encoded", "serialized", "compressed", "packed",
  ]
}
