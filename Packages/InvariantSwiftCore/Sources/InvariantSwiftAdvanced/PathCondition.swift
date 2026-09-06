/// A path condition observed during program execution.
public struct PathCondition: Sendable {
  public let conditions: [SMTExpression]
  public let variables: [SMTVariableDeclaration]

  public init(
    conditions: [SMTExpression],
    variables: [SMTVariableDeclaration]
  ) {
    self.conditions = conditions
    self.variables = variables
  }

  /// Checks whether the path condition is satisfiable.
  public func isSatisfiable(using solver: SMTSolver) async -> Bool {
    await solver.checkSat(constraint)
  }

  /// Generates inputs that satisfy the path condition.
  public func generateInputs(
    using solver: SMTSolver,
    count: Int = 5
  ) async -> [[String: SMTValue]] {
    let results = await solver.generateSolutions(
      constraint,
      maxSolutions: count
    )
    return results.compactMap { result in
      guard case .satisfiable(let model) = result else { return nil }
      return model
    }
  }

  private var constraint: SMTConstraint {
    let conjunction = conditions.reduce(
      SMTExpression.constant(.bool(true))
    ) { partial, condition in
      .binary(.and, partial, condition)
    }
    return SMTConstraint(
      expression: conjunction,
      variables: variables
    )
  }
}
