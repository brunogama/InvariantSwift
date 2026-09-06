extension SMTExpression {
  /// Creates an arithmetic expression.
  public static func arithmetic(
    _ lhs: SMTExpression,
    _ operation: SMTBinaryOp,
    _ rhs: SMTExpression
  ) -> SMTExpression {
    .binary(operation, lhs, rhs)
  }

  /// Creates a Boolean expression.
  public static func boolean(
    _ lhs: SMTExpression,
    _ operation: SMTBinaryOp,
    _ rhs: SMTExpression
  ) -> SMTExpression {
    .binary(operation, lhs, rhs)
  }

  /// Creates a closed range constraint.
  public static func range(
    _ expression: SMTExpression,
    min: SMTValue,
    max: SMTValue
  ) -> SMTExpression {
    .binary(
      .and,
      .binary(.lessThanOrEqual, .constant(min), expression),
      .binary(.lessThanOrEqual, expression, .constant(max))
    )
  }

  /// Creates a distinctness constraint.
  public static func distinct(_ expressions: [SMTExpression]) -> SMTExpression {
    guard expressions.count > 1 else { return .constant(.bool(true)) }
    let constraints = distinctPairs(expressions)
    return constraints.dropFirst().reduce(
      constraints.first ?? .constant(.bool(true))
    ) { partial, constraint in
      .binary(.and, partial, constraint)
    }
  }

  private static func distinctPairs(
    _ expressions: [SMTExpression]
  ) -> [SMTExpression] {
    var constraints: [SMTExpression] = []
    for firstIndex in expressions.indices {
      for secondIndex in expressions.indices where secondIndex > firstIndex {
        constraints.append(
          .binary(
            .notEquals,
            expressions[firstIndex],
            expressions[secondIndex]
          )
        )
      }
    }
    return constraints
  }
}
