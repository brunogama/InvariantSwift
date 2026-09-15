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
public struct SMTGenerator<Value: Sendable>: Sendable {
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
  ///
  /// A `count` of zero or less yields no values.
  public func generateMultiple(count: Int = 10) async -> [Value] {
    guard count > 0 else { return [] }
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

  /// Generates arrays of exactly `size` elements, each satisfying
  /// `elementGenerator`'s constraint.
  ///
  /// Each position becomes its own solver variable `x0`, `x1`, ... so the
  /// element constraint is asserted independently per slot. An empty `size`
  /// yields the empty array; a negative `size` yields no value.
  public static func array<Element>(
    size: Int,
    elementGenerator: SMTGenerator<Element>
  ) -> SMTGenerator<[Element]> {
    SMTGenerator<[Element]>(
      constraintBuilder: { _ in
        arrayConstraint(size: size, elementGenerator: elementGenerator)
      },
      valueExtractor: { model in
        arrayValue(from: model, size: size, elementGenerator: elementGenerator)
      },
      solver: elementGenerator.solver
    )
  }

  private static func arrayConstraint<Element>(
    size: Int,
    elementGenerator: SMTGenerator<Element>
  ) -> SMTConstraint {
    guard size > 0 else {
      return SMTConstraint(expression: .constant(.bool(true)))
    }
    var variables: [SMTVariableDeclaration] = []
    var expression = SMTExpression.constant(.bool(true))
    for index in 0..<size {
      let slot = SMTVariableDeclaration(name: elementName(index), sort: .int)
      let element = elementGenerator.constraintBuilder(slot)
      variables.append(contentsOf: element.variables)
      expression = .binary(.and, expression, element.expression)
    }
    return SMTConstraint(expression: expression, variables: variables)
  }

  private static func arrayValue<Element>(
    from model: [String: SMTValue],
    size: Int,
    elementGenerator: SMTGenerator<Element>
  ) -> [Element]? {
    guard size >= 0 else { return nil }
    var elements: [Element] = []
    elements.reserveCapacity(size)
    for index in 0..<size {
      // The element extractor reads the canonical name its own constraint
      // builder uses, so each slot is presented back under that name.
      guard
        let value = model[elementName(index)],
        let element = elementGenerator.valueExtractor([elementVariableName: value])
      else {
        return nil
      }
      elements.append(element)
    }
    return elements
  }

  private static func elementName(_ index: Int) -> String {
    "\(elementVariableName)\(index)"
  }

  private static var elementVariableName: String { "x" }

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
