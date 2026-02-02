// MARK: - Test Pattern Generation
// Extension for generating individual test patterns.

import Foundation

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
    """
    /// Codable roundtrip: encoding and decoding preserves value.
    @PropertyTest
    func test\(typeName)_codableRoundtrip(value: \(typeName)) throws {
      let encoded = try JSONEncoder().encode(value)
      let decoded = try JSONDecoder().decode(\(typeName).self, from: encoded)
      #expect(decoded == value, "Codable roundtrip should preserve value")
    }
    """
  }

  private func generateEquatableReflexiveTest(typeName: String) -> String {
    """
    /// Equatable reflexivity: x == x for all x.
    @PropertyTest
    func test\(typeName)_equatableReflexive(value: \(typeName)) {
      #expect(value == value, "Reflexivity: x == x")
    }
    """
  }

  private func generateEquatableSymmetricTest(typeName: String) -> String {
    """
    /// Equatable symmetry: x == y implies y == x.
    @PropertyTest
    func test\(typeName)_equatableSymmetric(a: \(typeName), b: \(typeName)) {
      if a == b {
        #expect(b == a, "Symmetry: a == b implies b == a")
      }
    }
    """
  }

  private func generateEquatableTransitiveTest(typeName: String) -> String {
    """
    /// Equatable transitivity: x == y && y == z implies x == z.
    @PropertyTest
    func test\(typeName)_equatableTransitive(a: \(typeName), b: \(typeName), c: \(typeName)) {
      if a == b && b == c {
        #expect(a == c, "Transitivity: a == b && b == c implies a == c")
      }
    }
    """
  }

  private func generateHashableConsistencyTest(typeName: String) -> String {
    """
    /// Hashable consistency: equal values must have equal hash values.
    @PropertyTest
    func test\(typeName)_hashableConsistency(a: \(typeName), b: \(typeName)) {
      if a == b {
        #expect(a.hashValue == b.hashValue, "Equal values must have equal hash values")
      }
    }
    """
  }

  private func generateComparableIrreflexiveTest(typeName: String) -> String {
    """
    /// Comparable irreflexivity: !(x < x) for all x.
    @PropertyTest
    func test\(typeName)_comparableIrreflexive(value: \(typeName)) {
      #expect(!(value < value), "Irreflexivity: !(x < x)")
    }
    """
  }

  private func generateComparableAsymmetricTest(typeName: String) -> String {
    """
    /// Comparable asymmetry: x < y implies !(y < x).
    @PropertyTest
    func test\(typeName)_comparableAsymmetric(a: \(typeName), b: \(typeName)) {
      if a < b {
        #expect(!(b < a), "Asymmetry: a < b implies !(b < a)")
      }
    }
    """
  }

  private func generateComparableTransitiveTest(typeName: String) -> String {
    """
    /// Comparable transitivity: x < y && y < z implies x < z.
    @PropertyTest
    func test\(typeName)_comparableTransitive(a: \(typeName), b: \(typeName), c: \(typeName)) {
      if a < b && b < c {
        #expect(a < c, "Transitivity: a < b && b < c implies a < c")
      }
    }
    """
  }

  private func generateComparableTrichotomyTest(typeName: String) -> String {
    """
    /// Comparable trichotomy: exactly one of <, ==, > holds.
    @PropertyTest
    func test\(typeName)_comparableTrichotomy(a: \(typeName), b: \(typeName)) {
      let isLess = a < b
      let isEqual = a == b
      let isGreater = b < a
      let exactlyOne = [isLess, isEqual, isGreater].filter { $0 }.count == 1
      #expect(exactlyOne, "Trichotomy: exactly one of <, ==, > holds")
    }
    """
  }
}
