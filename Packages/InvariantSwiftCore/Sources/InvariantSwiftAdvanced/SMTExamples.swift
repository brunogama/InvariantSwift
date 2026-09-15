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
  /// Generates integers that satisfy a simplified prime constraint.
  public static func primeNumberConstraints() -> SMTGenerator<Int> {
    SMTGenerator<Int>.integerInRange(
      2...1000,
      additionalConstraints: { expression in
        .binary(.greaterThan, expression, .constant(.int(1)))
      }
    )
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
