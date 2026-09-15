/// One integer Pythagorean triple.
public struct PythagoreanTriple: Sendable {
  public let first: Int
  public let second: Int
  public let hypotenuse: Int

  public init(first: Int, second: Int, hypotenuse: Int) {
    self.first = first
    self.second = second
    self.hypotenuse = hypotenuse
  }
}

/// Examples of SMT-assisted property-test generators.
public enum SMTExamples {
  /// The inclusive range ``primeNumberConstraints()`` draws from.
  public static let primeRange = 2...1000

  /// Generates prime integers in ``primeRange``.
  ///
  /// Primality is encoded without quantifiers: every composite value in the
  /// range has a prime factor no larger than the square root of the upper
  /// bound, so excluding those divisors is exact here. A value may equal one
  /// of the divisors, which is why each clause admits that case.
  public static func primeNumberConstraints() -> SMTGenerator<Int> {
    SMTGenerator<Int>.integerInRange(
      primeRange,
      additionalConstraints: { expression in
        conjoin(primalityConstraints(for: expression))
      }
    )
  }

  private static func primalityConstraints(
    for expression: SMTExpression
  ) -> [SMTExpression] {
    smallPrimes(upTo: primeRange.upperBound).map { divisor in
      .binary(
        .or,
        .binary(.equals, expression, .constant(.int(divisor))),
        .binary(
          .notEquals,
          .binary(.modulo, expression, .constant(.int(divisor))),
          .constant(.int(0))
        )
      )
    }
  }

  /// Every prime no larger than the square root of `bound`.
  ///
  /// Trial division by these is sufficient to decide primality up to `bound`.
  private static func smallPrimes(upTo bound: Int) -> [Int] {
    var primes: [Int] = []
    var candidate = 2
    while candidate * candidate <= bound {
      if primes.allSatisfy({ candidate % $0 != 0 }) { primes.append(candidate) }
      candidate += 1
    }
    return primes
  }

  /// Generates positive integer Pythagorean triples.
  public static func pythagoreanTripleConstraints()
    -> SMTGenerator<PythagoreanTriple>
  {
    SMTGenerator(
      constraintBuilder: { _ in pythagoreanConstraint() },
      valueExtractor: triple(from:)
    )
  }

  private static func pythagoreanConstraint() -> SMTConstraint {
    let variables = tripleVariables
    let squares = variables.map {
      SMTExpression.binary(.multiply, .variable($0.name), .variable($0.name))
    }
    let equality = SMTExpression.binary(
      .equals,
      .binary(.plus, squares[0], squares[1]),
      squares[2]
    )
    let expressions = [equality] + positiveConstraints(variables)
    return SMTConstraint(
      expression: conjoin(expressions),
      variables: variables
    )
  }

  private static var tripleVariables: [SMTVariableDeclaration] {
    [
      SMTVariableDeclaration(name: "a", sort: .int),
      SMTVariableDeclaration(name: "b", sort: .int),
      SMTVariableDeclaration(name: "c", sort: .int),
    ]
  }

  private static func positiveConstraints(
    _ variables: [SMTVariableDeclaration]
  ) -> [SMTExpression] {
    variables.map {
      .binary(.greaterThan, .variable($0.name), .constant(.int(0)))
    }
  }

  private static func conjoin(
    _ expressions: [SMTExpression]
  ) -> SMTExpression {
    expressions.reduce(.constant(.bool(true))) { partial, expression in
      .binary(.and, partial, expression)
    }
  }

  private static func triple(
    from model: [String: SMTValue]
  ) -> PythagoreanTriple? {
    guard case .int(let first) = model["a"] else { return nil }
    guard case .int(let second) = model["b"] else { return nil }
    guard case .int(let hypotenuse) = model["c"] else { return nil }
    return PythagoreanTriple(
      first: first,
      second: second,
      hypotenuse: hypotenuse
    )
  }
}
