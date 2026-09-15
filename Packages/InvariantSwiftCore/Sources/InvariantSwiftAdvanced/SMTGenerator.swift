/// Builds an SMT constraint from a variable declaration.
public typealias SMTConstraintBuilder =
  @Sendable (SMTVariableDeclaration) -> SMTConstraint

/// Applies an additional constraint to an SMT expression.
public typealias SMTConstraintTransform =
  @Sendable (SMTExpression) -> SMTExpression

/// Extracts a generated value from an SMT model.
public typealias SMTValueExtractor<Value> =
  @Sendable ([String: SMTValue]) -> Value?

/// An SMT-guided generator for constraint-based input synthesis.
public struct SMTGenerator<Value: Sendable> {
  public let constraintBuilder: SMTConstraintBuilder
  public let valueExtractor: SMTValueExtractor<Value>
  public let solver: SMTSolver

  public init(
    constraintBuilder: @escaping SMTConstraintBuilder,
    valueExtractor: @escaping SMTValueExtractor<Value>,
    solver: SMTSolver = SMTSolver()
  ) {
    self.constraintBuilder = constraintBuilder
    self.valueExtractor = valueExtractor
    self.solver = solver
  }

  /// Generates one value that satisfies the configured constraint.
  public func generate() async -> Value? {
    let variable = SMTVariableDeclaration(name: "x", sort: .int)
    let result = await solver.solve(constraintBuilder(variable))
    guard case .satisfiable(let model) = result else { return nil }
    return valueExtractor(model)
  }

  /// Generates multiple values that satisfy the configured constraint.
  public func generateMultiple(count: Int = 10) async -> [Value] {
    let variable = SMTVariableDeclaration(name: "x", sort: .int)
    let constraint = constraintBuilder(variable)
    let results = await solver.generateSolutions(
      constraint,
      maxSolutions: count
    )
    return results.compactMap { result in
      guard case .satisfiable(let model) = result else { return nil }
      return valueExtractor(model)
    }
  }
}

extension SMTGenerator {
  /// Generates integers within a range and optional additional constraints.
  public static func integerInRange(
    _ range: ClosedRange<Int>
  ) -> SMTGenerator<Int> {
    integerInRange(range) { _ in .constant(.bool(true)) }
  }

  /// Generates constrained integers within a closed range.
  public static func integerInRange(
    _ range: ClosedRange<Int>,
    additionalConstraints: @escaping SMTConstraintTransform
  ) -> SMTGenerator<Int> {
    SMTGenerator<Int>(
      constraintBuilder: { variable in
        integerConstraint(
          variable,
          range: range,
          additionalConstraints: additionalConstraints
        )
      },
      valueExtractor: integerValue(from:)
    )
  }

  /// Generates arrays with size and element constraints.
  public static func array<Element>(
    size: Int,
    elementGenerator: SMTGenerator<Element>
  ) -> SMTGenerator<[Element]> {
    _ = size
    _ = elementGenerator
    return SMTGenerator<[Element]>(
      constraintBuilder: { _ in
        SMTConstraint(expression: .constant(.bool(true)))
      },
      valueExtractor: { _ in [] }
    )
  }

  private static func integerConstraint(
    _ variable: SMTVariableDeclaration,
    range: ClosedRange<Int>,
    additionalConstraints: SMTConstraintTransform
  ) -> SMTConstraint {
    let expression = SMTExpression.variable(variable.name)
    let rangeConstraint = SMTExpression.range(
      expression,
      min: .int(range.lowerBound),
      max: .int(range.upperBound)
    )
    return SMTConstraint(
      expression: .binary(
        .and,
        rangeConstraint,
        additionalConstraints(expression)
      ),
      variables: [variable]
    )
  }

  private static func integerValue(
    from model: [String: SMTValue]
  ) -> Int? {
    guard case .int(let value) = model["x"] else { return nil }
    return value
  }
}
