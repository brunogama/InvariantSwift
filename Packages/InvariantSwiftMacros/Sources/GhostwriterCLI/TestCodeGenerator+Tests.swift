// MARK: - TestCodeGenerator Test Generation
// Individual test code generation for each pattern.

import Foundation

extension TestCodeGenerator {
  /// Generate a single test for a type and pattern.
  public func generateTest(
    for type: ExtractedTypeInfo,
    pattern: GhostwriterTestPattern
  ) -> String {
    let name = type.name

    switch pattern {
    case .codableRoundtrip:
      return codableRoundtripTest(typeName: name)

    case .equatableReflexive:
      return equatableReflexiveTest(typeName: name)

    case .equatableSymmetric:
      return equatableSymmetricTest(typeName: name)

    case .equatableTransitive:
      return equatableTransitiveTest(typeName: name)

    case .hashableConsistency:
      return hashableConsistencyTest(typeName: name)

    case .comparableIrreflexive:
      return comparableIrreflexiveTest(typeName: name)

    case .comparableAsymmetric:
      return comparableAsymmetricTest(typeName: name)

    case .comparableTransitive:
      return comparableTransitiveTest(typeName: name)

    case .comparableTrichotomy:
      return comparableTrichotomyTest(typeName: name)
    }
  }

  private func codableRoundtripTest(typeName: String) -> String {
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

  private func equatableReflexiveTest(typeName: String) -> String {
    """
    /// Equatable reflexivity: x == x for all x.
    @PropertyTest
    func test\(typeName)_equatableReflexive(value: \(typeName)) {
      #expect(value == value, "Reflexivity: x == x")
    }
    """
  }

  private func equatableSymmetricTest(typeName: String) -> String {
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

  private func equatableTransitiveTest(typeName: String) -> String {
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

  private func hashableConsistencyTest(typeName: String) -> String {
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

  private func comparableIrreflexiveTest(typeName: String) -> String {
    """
    /// Comparable irreflexivity: !(x < x) for all x.
    @PropertyTest
    func test\(typeName)_comparableIrreflexive(value: \(typeName)) {
      #expect(!(value < value), "Irreflexivity: !(x < x)")
    }
    """
  }

  private func comparableAsymmetricTest(typeName: String) -> String {
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

  private func comparableTransitiveTest(typeName: String) -> String {
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

  private func comparableTrichotomyTest(typeName: String) -> String {
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
