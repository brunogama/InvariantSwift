import InvariantSwiftExpansionSupport

extension TestCodeGenerator {
  /// Plans candidate-only or combined executable tests for a type.
  func plannedTests(
    for type: ExtractedTypeInfo,
    discoverLaws: Bool = false,
    identity: GeneratedTypeIdentity? = nil
  ) -> [GhostwriterGeneratedTest] {
    let identity = identity ?? GeneratedTypeIdentity(type: type)
    let candidateTests = plannedCandidateTests(for: type, identity: identity)
    let tests: [GhostwriterGeneratedTest]
    if discoverLaws {
      tests = candidateTests
    } else {
      let catalogTests = detectPatterns(for: type).map {
        plannedTest(for: type, pattern: $0, identity: identity)
      }
      tests =
        candidateTests + catalogTests
        + plannedFieldLawTests(for: type, identity: identity)
    }

    var names = Set<String>()
    return tests.filter { names.insert($0.functionName).inserted }
  }

  /// Number of executable tests planned for a type.
  public func generatedTestCount(
    for type: ExtractedTypeInfo,
    discoverLaws: Bool = false
  ) -> Int {
    plannedTests(for: type, discoverLaws: discoverLaws).count
  }

  func plannedSections(
    for types: [ExtractedTypeInfo],
    consumerModule: String?,
    discoverLaws: Bool
  ) -> [GhostwriterGeneratedSection] {
    types.compactMap { type in
      let identity = GeneratedTypeIdentity(type: type, consumerModule: consumerModule)
      let tests = plannedTests(
        for: type,
        discoverLaws: discoverLaws,
        identity: identity
      )
      guard !tests.isEmpty else { return nil }
      return GhostwriterGeneratedSection(title: identity.sectionTitle, tests: tests)
    }
  }

  func plannedFieldLawTests(
    for type: ExtractedTypeInfo,
    identity: GeneratedTypeIdentity? = nil
  ) -> [GhostwriterGeneratedTest] {
    guard type.kind == "struct",
      type.genericParameters.isEmpty,
      detectPatterns(for: type).contains(.equatableReflexive),
      type.hasArbitraryAttribute || canAutoGenerateArbitrary(for: type)
    else { return [] }

    let writableProperties = type.properties.filter { property in
      property.isMutable && property.accessLevel >= .internal
        && Self.knownFieldLawTypes.contains(property.typeName)
    }
    let identity = identity ?? GeneratedTypeIdentity(type: type)
    return writableProperties.map { property in
      fieldLawTest(identity: identity, property: property)
    }
  }

  private static let knownFieldLawTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Bool", "String", "Character", "UUID",
  ]

  private func fieldLawTest(
    identity: GeneratedTypeIdentity,
    property: ExtractedProperty
  ) -> GhostwriterGeneratedTest {
    let field = property.name
    return GhostwriterGeneratedTest(
      docComment: "Writable \(field) obeys Put-Get, Get-Put, and Put-Put.",
      functionName: "test\(identity.functionNameComponent)_\(field)_lensLaws",
      parameters: [
        ExpansionParameter(name: "root", type: identity.reference),
        ExpansionParameter(name: "value", type: property.typeName),
        ExpansionParameter(name: "replacement", type: property.typeName),
      ],
      bodyStatements: [
        .varBinding(name: "updated", initializer: id("root")),
        .assignment(target: member("updated", field), value: id("value")),
        expect(binary(member("updated", field), "==", id("value")), "Put-Get must hold"),
        .varBinding(name: "restored", initializer: id("root")),
        .assignment(target: member("restored", field), value: member("root", field)),
        expect(binary(id("restored"), "==", id("root")), "Get-Put must hold"),
        .varBinding(name: "twice", initializer: id("root")),
        .assignment(target: member("twice", field), value: id("value")),
        .assignment(target: member("twice", field), value: id("replacement")),
        .varBinding(name: "once", initializer: id("root")),
        .assignment(target: member("once", field), value: id("replacement")),
        expect(binary(id("twice"), "==", id("once")), "Put-Put must hold"),
      ]
    )
  }
}
