// MARK: - ISP-0009: Test Generator
// Template-based property test code generation.

import Foundation

// MARK: - Test Generator

// swiftlint:disable:next orphaned_doc_comment
/// Generates property test code from type information.
// swiftlint:disable:next type_body_length
public struct TestGenerator: Sendable {

  /// Configuration for test generation
  public let config: GhostwriterConfig

  public init(config: GhostwriterConfig) {
    self.config = config
  }

  // MARK: - Main Generation

  /// Generate all tests for a type.
  /// Returns empty array if the type is not in supportedArbitraryTypes.
  public func generateTests(for typeInfo: TypeInfo) -> [GeneratedTest] {
    // Skip types without known Arbitrary generators (unless supportedArbitraryTypes is empty)
    if !config.supportedArbitraryTypes.isEmpty
      && !config.supportedArbitraryTypes.contains(typeInfo.name)
    {
      if config.verbose {
        // swiftlint:disable:next no_print
        print("  ⚠️ Skipping \(typeInfo.name): no Arbitrary generator available")
      }
      return []
    }

    var tests: [GeneratedTest] = []

    let patterns =
      config.patterns.isEmpty
      ? typeInfo.applicablePatterns
      : typeInfo.applicablePatterns.filter { config.patterns.contains($0) }

    for pattern in patterns {
      if let test = generateTest(for: typeInfo, pattern: pattern) {
        tests.append(test)
      }
    }

    return tests
  }

  // swiftlint:disable:next orphaned_doc_comment
  /// Generate a single test for a pattern.
  // swiftlint:disable:next cyclomatic_complexity
  public func generateTest(for typeInfo: TypeInfo, pattern: TestPattern) -> GeneratedTest? {
    let code: String

    switch pattern {
    case .codableRoundtrip:
      code = generateCodableRoundtrip(for: typeInfo)

    case .equatableReflexive:
      code = generateEquatableReflexive(for: typeInfo)

    case .equatableSymmetric:
      code = generateEquatableSymmetric(for: typeInfo)

    case .equatableTransitive:
      code = generateEquatableTransitive(for: typeInfo)

    case .hashableConsistency:
      code = generateHashableConsistency(for: typeInfo)

    case .comparableIrreflexive:
      code = generateComparableIrreflexive(for: typeInfo)

    case .comparableAsymmetric:
      code = generateComparableAsymmetric(for: typeInfo)

    case .comparableTransitive:
      code = generateComparableTransitive(for: typeInfo)

    case .comparableTrichotomy:
      code = generateComparableTrichotomy(for: typeInfo)

    case .idempotent:
      code = generateIdempotent(for: typeInfo)

    case .inverseFunctions:
      code = generateInverseFunctions(for: typeInfo)

    case .collectionCount:
      code = generateCollectionCount(for: typeInfo)

    case .collectionIndices:
      code = generateCollectionIndices(for: typeInfo)

    case .identifiableStability:
      code = generateIdentifiableStability(for: typeInfo)

    case .rawRepresentableRoundtrip:
      code = generateRawRepresentableRoundtrip(for: typeInfo)

    case .numericAdditiveIdentity:
      code = generateNumericAdditiveIdentity(for: typeInfo)

    case .numericCommutativity:
      code = generateNumericCommutativity(for: typeInfo)

    case .numericAssociativity:
      code = generateNumericAssociativity(for: typeInfo)

    case .additiveArithmeticZero:
      code = generateAdditiveArithmeticZero(for: typeInfo)

    case .collectionBounds:
      code = generateCollectionBounds(for: typeInfo)

    case .sequenceIteration:
      code = generateSequenceIteration(for: typeInfo)

    case .bidirectionalSymmetry:
      code = generateBidirectionalSymmetry(for: typeInfo)
    }

    let testName = "\(config.testPrefix)\(typeInfo.name)_\(pattern.rawValue)"

    return GeneratedTest(
      name: testName,
      sourceFile: typeInfo.sourceFile,
      sourceLine: typeInfo.line,
      typeName: typeInfo.name,
      pattern: pattern.rawValue,
      code: code
    )
  }

  // MARK: - Codable Tests

  private func generateCodableRoundtrip(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Codable roundtrip: encoding and decoding preserves value.
      /// Pattern: \(TestPattern.codableRoundtrip.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_codableRoundtrip(value: \(typeName)) throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(value)
        let decoded = try decoder.decode(\(typeName).self, from: encoded)

        #expect(decoded == value, "Codable roundtrip should preserve value")
      }
      """
  }

  // MARK: - Equatable Tests

  private func generateEquatableReflexive(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Equatable reflexivity: x == x for all x.
      /// Pattern: \(TestPattern.equatableReflexive.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_equatableReflexive(value: \(typeName)) {
        #expect(value == value, "Reflexivity: x == x")
      }
      """
  }

  private func generateEquatableSymmetric(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Equatable symmetry: x == y implies y == x.
      /// Pattern: \(TestPattern.equatableSymmetric.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_equatableSymmetric(a: \(typeName), b: \(typeName)) {
        if a == b {
          #expect(b == a, "Symmetry: a == b implies b == a")
        }
      }
      """
  }

  private func generateEquatableTransitive(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Equatable transitivity: x == y && y == z implies x == z.
      /// Pattern: \(TestPattern.equatableTransitive.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_equatableTransitive(
        a: \(typeName),
        b: \(typeName),
        c: \(typeName)
      ) {
        if a == b && b == c {
          #expect(a == c, "Transitivity: a == b && b == c implies a == c")
        }
      }
      """
  }

  // MARK: - Hashable Tests

  private func generateHashableConsistency(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Hashable consistency: equal values must have equal hash values.
      /// Pattern: \(TestPattern.hashableConsistency.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_hashableConsistency(a: \(typeName), b: \(typeName)) {
        if a == b {
          #expect(
            a.hashValue == b.hashValue,
            "Equal values must have equal hash values"
          )
        }
      }
      """
  }

  // MARK: - Comparable Tests

  private func generateComparableIrreflexive(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Comparable irreflexivity: !(x < x) for all x.
      /// Pattern: \(TestPattern.comparableIrreflexive.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_comparableIrreflexive(value: \(typeName)) {
        #expect(!(value < value), "Irreflexivity: !(x < x)")
      }
      """
  }

  private func generateComparableAsymmetric(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Comparable asymmetry: x < y implies !(y < x).
      /// Pattern: \(TestPattern.comparableAsymmetric.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_comparableAsymmetric(a: \(typeName), b: \(typeName)) {
        if a < b {
          #expect(!(b < a), "Asymmetry: a < b implies !(b < a)")
        }
      }
      """
  }

  private func generateComparableTransitive(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Comparable transitivity: x < y && y < z implies x < z.
      /// Pattern: \(TestPattern.comparableTransitive.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_comparableTransitive(
        a: \(typeName),
        b: \(typeName),
        c: \(typeName)
      ) {
        if a < b && b < c {
          #expect(a < c, "Transitivity: a < b && b < c implies a < c")
        }
      }
      """
  }

  private func generateComparableTrichotomy(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Comparable trichotomy: exactly one of <, ==, > holds.
      /// Pattern: \(TestPattern.comparableTrichotomy.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_comparableTrichotomy(a: \(typeName), b: \(typeName)) {
        let isLess = a < b
        let isEqual = a == b
        let isGreater = b < a
        let exactlyOne = [isLess, isEqual, isGreater].filter { $0 }.count == 1
        #expect(exactlyOne, "Trichotomy: exactly one of <, ==, > holds")
      }
      """
  }

  // MARK: - Idempotent Tests

  private func generateIdempotent(for typeInfo: TypeInfo) -> String {
    // Find an idempotent-looking method
    guard let method = typeInfo.methods.first(where: { $0.looksIdempotent }) else {
      return "// No idempotent method found for \(typeInfo.name)"
    }

    let typeName = typeInfo.name
    let methodName = method.name

    if method.isMutating {
      return """
        /// Idempotent: applying \(methodName) twice equals applying once.
        /// Pattern: \(TestPattern.idempotent.description)
        @PropertyTest
        func \(config.testPrefix)\(typeName)_\(methodName)_idempotent(value: \(typeName)) {
          var once = value
          once.\(methodName)()

          var twice = once
          twice.\(methodName)()

          #expect(once == twice, "\(methodName) should be idempotent")
        }
        """
    } else {
      return """
        /// Idempotent: applying \(methodName) twice equals applying once.
        /// Pattern: \(TestPattern.idempotent.description)
        @PropertyTest
        func \(config.testPrefix)\(typeName)_\(methodName)_idempotent(value: \(typeName)) {
          let once = value.\(methodName)()
          let twice = once.\(methodName)()
          #expect(once == twice, "\(methodName) should be idempotent")
        }
        """
    }
  }

  // MARK: - Inverse Function Tests

  private func generateInverseFunctions(for typeInfo: TypeInfo) -> String {
    let encoder = typeInfo.methods.first { $0.looksLikeEncoder }
    let decoder = typeInfo.methods.first { $0.looksLikeDecoder }

    guard let enc = encoder, let dec = decoder else {
      return "// No inverse function pair found for \(typeInfo.name)"
    }

    let typeName = typeInfo.name
    let throwsKeyword = (enc.isThrowing || dec.isThrowing) ? "throws " : ""
    let tryKeyword = (enc.isThrowing || dec.isThrowing) ? "try " : ""

    return """
      /// Inverse functions: \(dec.name)(\(enc.name)(x)) == x.
      /// Pattern: \(TestPattern.inverseFunctions.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_\(enc.name)\(dec.name.capitalized)Roundtrip(
        value: \(typeName)
      ) \(throwsKeyword){
        let encoded = \(tryKeyword)value.\(enc.name)()
        let decoded = \(tryKeyword)\(typeName).\(dec.name)(encoded)
        #expect(decoded == value, "\(dec.name)(\(enc.name)(x)) should equal x")
      }
      """
  }

  // MARK: - Collection Tests

  private func generateCollectionCount(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Collection count matches iteration count.
      /// Pattern: \(TestPattern.collectionCount.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_countMatchesIteration(collection: \(typeName)) {
        var iterationCount = 0
        for _ in collection {
          iterationCount += 1
        }
        #expect(
          iterationCount == collection.count,
          "Iteration count should match count property"
        )
      }
      """
  }

  private func generateCollectionIndices(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Collection indices are all valid.
      /// Pattern: \(TestPattern.collectionIndices.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_indicesValid(collection: \(typeName)) {
        for index in collection.indices {
          // Accessing should not crash
          _ = collection[index]
        }
        #expect(Bool(true), "All indices should be valid")
      }
      """
  }

  private func generateCollectionBounds(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Collection startIndex/endIndex consistency.
      /// Pattern: \(TestPattern.collectionBounds.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_collectionBounds(collection: \(typeName)) {
        if collection.isEmpty {
          #expect(collection.startIndex == collection.endIndex, "Empty: start == end")
        } else {
          #expect(collection.startIndex < collection.endIndex, "Non-empty: start < end")
        }
      }
      """
  }

  // MARK: - Identifiable Tests

  private func generateIdentifiableStability(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Identifiable: id is stable across accesses.
      /// Pattern: \(TestPattern.identifiableStability.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_identifiableStability(value: \(typeName)) {
        let id1 = value.id
        let id2 = value.id
        #expect(id1 == id2, "Identifiable: id should be stable across accesses")
      }
      """
  }

  // MARK: - RawRepresentable Tests

  private func generateRawRepresentableRoundtrip(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// RawRepresentable roundtrip: init(rawValue:) → rawValue == original.
      /// Pattern: \(TestPattern.rawRepresentableRoundtrip.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_rawRepresentableRoundtrip(value: \(typeName)) {
        let raw = value.rawValue
        let recreated = \(typeName)(rawValue: raw)
        #expect(recreated == value, "RawRepresentable roundtrip should preserve value")
      }
      """
  }

  // MARK: - Numeric Tests

  private func generateNumericAdditiveIdentity(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Numeric additive identity: x + 0 == x.
      /// Pattern: \(TestPattern.numericAdditiveIdentity.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_additiveIdentity(value: \(typeName)) {
        #expect(value + .zero == value, "Additive identity: x + 0 == x")
        #expect(\(typeName).zero + value == value, "Additive identity: 0 + x == x")
      }
      """
  }

  private func generateNumericCommutativity(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Numeric commutativity: a + b == b + a.
      /// Pattern: \(TestPattern.numericCommutativity.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_commutativity(a: \(typeName), b: \(typeName)) {
        #expect(a + b == b + a, "Commutativity: a + b == b + a")
      }
      """
  }

  private func generateNumericAssociativity(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Numeric associativity: (a + b) + c == a + (b + c).
      /// Pattern: \(TestPattern.numericAssociativity.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_associativity(a: \(typeName), b: \(typeName), c: \(typeName)) {
        #expect((a + b) + c == a + (b + c), "Associativity: (a + b) + c == a + (b + c)")
      }
      """
  }

  private func generateAdditiveArithmeticZero(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// AdditiveArithmetic zero identity.
      /// Pattern: \(TestPattern.additiveArithmeticZero.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_zeroIdentity(value: \(typeName)) {
        #expect(value - value == .zero, "x - x == 0")
        #expect(value + .zero == value, "x + 0 == x")
      }
      """
  }

  // MARK: - Sequence Tests

  private func generateSequenceIteration(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// Sequence iteration is consistent.
      /// Pattern: \(TestPattern.sequenceIteration.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_sequenceIteration(sequence: \(typeName)) {
        // Iterate twice and compare results
        let array1 = Array(sequence)
        let array2 = Array(sequence)
        #expect(array1 == array2, "Sequence iteration should be consistent")
      }
      """
  }

  // MARK: - BidirectionalCollection Tests

  private func generateBidirectionalSymmetry(for typeInfo: TypeInfo) -> String {
    let typeName = typeInfo.name
    return """
      /// BidirectionalCollection index symmetry.
      /// Pattern: \(TestPattern.bidirectionalSymmetry.description)
      @PropertyTest
      func \(config.testPrefix)\(typeName)_bidirectionalSymmetry(collection: \(typeName)) {
        for index in collection.indices {
          if index != collection.endIndex {
            let next = collection.index(after: index)
            if next != collection.endIndex {
              let back = collection.index(before: next)
              #expect(back == index, "index(before: index(after: i)) == i")
            }
          }
        }
      }
      """
  }

  // MARK: - File Generation

  /// Generate a complete test file for a source file's types.
  public func generateTestFile(for sourceFile: SourceFileInfo) -> String {
    var lines: [String] = []

    // File header
    lines.append("// Generated by InvariantSwift Ghostwriter")
    lines.append("// Source: \(sourceFile.path)")
    lines.append("// Generated: \(ISO8601DateFormatter().string(from: Date()))")
    lines.append("//")
    lines.append("// DO NOT EDIT - Regenerate with: functest ghostwrite")
    lines.append("")
    lines.append("import Testing")
    lines.append("import Foundation")
    lines.append("import InvariantSwiftCore")
    lines.append("import InvariantSwiftTesting")
    lines.append("import InvariantSwiftMacroAPI")
    lines.append("@testable import InvariantSwift")
    lines.append("")

    // Add any additional imports from source file
    for importStmt in sourceFile.imports where !["Foundation", "Swift"].contains(importStmt) {
      lines.append("import \(importStmt)")
    }
    lines.append("")

    // Generate test struct
    let fileName = URL(fileURLWithPath: sourceFile.path).deletingPathExtension().lastPathComponent
    lines.append("@Suite(\"\(fileName) Property Tests\")")
    lines.append("struct \(fileName)\(config.testSuffix) {")
    lines.append("")

    // Generate tests for each testable type
    for typeInfo in sourceFile.testableTypes {
      lines.append("  // MARK: - \(typeInfo.name) Tests")
      lines.append("")

      let tests = generateTests(for: typeInfo)
      for test in tests {
        // Indent the test code
        let indentedCode = test.code.split(separator: "\n").map { "  \($0)" }.joined(
          separator: "\n"
        )
        lines.append(indentedCode)
        lines.append("")
      }
    }

    lines.append("}")
    lines.append("")

    return lines.joined(separator: "\n")
  }
  // swiftlint:disable:next file_length
}
