/// An expression in the SMT-LIB language.
public indirect enum SMTExpression: Sendable, CustomStringConvertible {
  case variable(String)
  case constant(SMTValue)
  case function(String, [Self])
  case binary(SMTBinaryOp, Self, Self)
  case unary(SMTUnaryOp, Self)
  case quantified(SMTQuantifier, [(String, SMTSort)], Self)
  case letBinding([(String, Self)], Self)

  public var description: String {
    switch self {
    case .variable(let name):
      return name

    case .constant(let value):
      return value.description

    case .function(let name, let arguments):
      return "(\(name) \(arguments.smtDescriptions))"

    case .binary(let operation, let lhs, let rhs):
      return "(\(operation.rawValue) \(lhs) \(rhs))"

    case .unary(let operation, let expression):
      return "(\(operation.rawValue) \(expression))"

    case .quantified(let quantifier, let variables, let body):
      return quantifiedDescription(quantifier, variables: variables, body: body)

    case .letBinding(let bindings, let body):
      return letDescription(bindings, body: body)
    }
  }

  private func quantifiedDescription(
    _ quantifier: SMTQuantifier,
    variables: [(String, SMTSort)],
    body: Self
  ) -> String {
    let declarations =
      variables
      .map { "(\($0.0) \($0.1.description))" }
      .joined(separator: " ")
    return "(\(quantifier.rawValue) (\(declarations)) \(body))"
  }

  private func letDescription(
    _ bindings: [(String, Self)],
    body: Self
  ) -> String {
    let declarations =
      bindings
      .map { "(\($0.0) \($0.1.description))" }
      .joined(separator: " ")
    return "(let (\(declarations)) \(body))"
  }
}

/// A typed SMT value.
public enum SMTValue: Sendable, CustomStringConvertible {
  case bool(Bool)
  case int(Int)
  case real(Double)
  case string(String)
  case bitVector(UInt64, width: Int)
  case array([Self])

  public var description: String {
    switch self {
    case .bool(let value):
      return value ? "true" : "false"

    case .int(let value):
      return String(value)

    case .real(let value):
      return String(value)

    case .string(let value):
      return "\"\(value)\""

    case .bitVector(let value, let width):
      return "#b\(String(value, radix: 2).leftPadded(to: width))"

    case .array(let elements):
      return "(\(elements.smtDescriptions))"
    }
  }
}

/// An SMT sort.
public indirect enum SMTSort: Sendable, CustomStringConvertible {
  case bool
  case int
  case real
  case string
  case bitVector(Int)
  case array(Self, Self)
  case uninterpreted(String)
  case custom(String, [Self])

  public var description: String {
    switch self {
    case .bool:
      return "Bool"

    case .int:
      return "Int"

    case .real:
      return "Real"

    case .string:
      return "String"

    case .bitVector(let width):
      return "(_ BitVec \(width))"

    case .array(let index, let element):
      return "(Array \(index) \(element))"

    case .uninterpreted(let name):
      return name

    case .custom(let name, let parameters):
      return "(\(name) \(parameters.smtDescriptions))"
    }
  }
}

/// A binary SMT operator.
public enum SMTBinaryOp: String, Sendable {
  case and, or
  case implies = "=>"
  case equals = "="
  case notEquals = "distinct"
  case lessThan = "<"
  case lessThanOrEqual = "<="
  case greaterThan = ">"
  case greaterThanOrEqual = ">="
  case plus = "+"
  case minus = "-"
  case multiply = "*"
  case divide = "/"
  case modulo = "mod"
  case quotient = "div"
  case bitwiseAnd = "bvand"
  case bitwiseOr = "bvor"
  case bitwiseXor = "bvxor"
  case leftShift = "bvshl"
  case rightShift = "bvlshr"
  case arraySelect = "select"
  case arrayStore = "store"
}

/// A unary SMT operator.
public enum SMTUnaryOp: String, Sendable {
  case not
  case minus = "-"
  case bitwiseNot = "bvnot"
}

/// An SMT quantifier.
public enum SMTQuantifier: String, Sendable {
  case forall, exists
}

/// A named variable and its sort.
public struct SMTVariableDeclaration: Sendable {
  public let name: String
  public let sort: SMTSort

  public init(name: String, sort: SMTSort) {
    self.name = name
    self.sort = sort
  }
}

/// A complete SMT constraint.
public struct SMTConstraint: Sendable {
  public let expression: SMTExpression
  public let variables: [SMTVariableDeclaration]
  public let assertions: [SMTExpression]

  public init(
    expression: SMTExpression,
    variables: [SMTVariableDeclaration] = [],
    assertions: [SMTExpression] = []
  ) {
    self.expression = expression
    self.variables = variables
    self.assertions = assertions
  }

  /// Converts the constraint to SMT-LIB 2 text.
  public func toSMTLIB2() -> String {
    var result = "(set-logic QF_LIA)\n"
    for variable in variables {
      result += "(declare-fun \(variable.name) () \(variable.sort))\n"
    }
    for assertion in assertions {
      result += "(assert \(assertion))\n"
    }
    result += "(assert \(expression))\n"
    result += "(check-sat)\n"
    result += "(get-model)\n"
    return result
  }
}

/// Result of SMT constraint solving.
public enum SMTResult: Sendable {
  case satisfiable([String: SMTValue])
  case unsatisfiable
  case unknown
  case timeout
  case error(String)
}

private extension Array where Element: CustomStringConvertible {
  var smtDescriptions: String {
    map(\.description).joined(separator: " ")
  }
}

private extension String {
  func leftPadded(to length: Int) -> String {
    let count = length - self.count
    guard count > 0 else { return self }
    return String(repeating: "0", count: count) + self
  }
}
