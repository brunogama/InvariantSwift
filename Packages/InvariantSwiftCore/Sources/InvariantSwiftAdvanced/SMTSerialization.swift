import Foundation

struct SMTLogicFeatures {
  private var hasIntegers = false
  private var hasReals = false
  private var hasStrings = false
  private var hasBitVectors = false
  private var hasArrays = false
  private var hasNonlinearArithmetic = false
  private var requiresGeneralLogic = false

  var logic: String {
    if requiresGeneralLogic { return "ALL" }
    if hasStrings {
      return hasArrays || hasBitVectors || hasReals || hasNonlinearArithmetic
        ? "ALL" : "QF_SLIA"
    }
    if hasArrays {
      if hasBitVectors && !hasIntegers && !hasReals && !hasNonlinearArithmetic {
        return "QF_AUFBV"
      }
      return hasBitVectors || hasReals || hasNonlinearArithmetic || !hasIntegers
        ? "ALL" : "QF_AUFLIA"
    }
    if hasBitVectors {
      return hasIntegers || hasReals || hasNonlinearArithmetic ? "ALL" : "QF_BV"
    }
    if hasReals {
      if hasNonlinearArithmetic { return hasIntegers ? "QF_NIRA" : "QF_NRA" }
      return hasIntegers ? "QF_LIRA" : "QF_LRA"
    }
    return hasNonlinearArithmetic ? "QF_NIA" : "QF_LIA"
  }

  mutating func include(_ sort: SMTSort) {
    switch sort {
    case .bool:
      break

    case .int:
      hasIntegers = true

    case .real:
      hasReals = true

    case .string:
      hasStrings = true

    case .bitVector:
      hasBitVectors = true

    case .array(let index, let element):
      hasArrays = true
      include(index)
      include(element)

    case .uninterpreted, .custom:
      requiresGeneralLogic = true
    }
  }

  mutating func include(_ value: SMTValue) {
    switch value {
    case .bool:
      break

    case .int:
      hasIntegers = true

    case .real:
      hasReals = true

    case .string:
      hasStrings = true

    case .bitVector:
      hasBitVectors = true

    case .array(let values, let elementSort):
      hasArrays = true
      hasIntegers = true
      if let elementSort { include(elementSort) }
      values.forEach { include($0) }
    }
  }

  mutating func include(_ expression: SMTExpression) {
    switch expression {
    case .variable:
      break

    case .constant(let value):
      include(value)

    case .function(_, let arguments):
      requiresGeneralLogic = true
      arguments.forEach { include($0) }

    case .binary(let operation, let lhs, let rhs):
      include(operation)
      include(lhs)
      include(rhs)

    case .unary(let operation, let operand):
      if case .bitwiseNot = operation { hasBitVectors = true }
      include(operand)

    case .quantified(_, let variables, let body):
      requiresGeneralLogic = true
      variables.forEach { include($0.1) }
      include(body)

    case .let_(let bindings, let body):
      bindings.forEach { include($0.1) }
      include(body)
    }
  }

  private mutating func include(_ operation: SMTBinaryOp) {
    switch operation {
    case .multiply:
      hasNonlinearArithmetic = true

    case .divide, .modulo, .quotient:
      requiresGeneralLogic = true

    case .bitwiseAnd, .bitwiseOr, .bitwiseXor, .leftShift, .rightShift:
      hasBitVectors = true

    case .arraySelect, .arrayStore:
      hasArrays = true

    default:
      break
    }
  }
}

extension SMTValue {
  var serializationIssue: String? {
    guard case .array(let elements, let explicitSort) = self else { return nil }
    guard let elementSort = explicitSort ?? Self.commonSort(of: elements) else {
      return "SMT array constants require an explicit element sort when empty or heterogeneous"
    }
    guard elements.allSatisfy({ $0.matches(elementSort) }) else {
      return "SMT array constant elements do not match \(elementSort.description)"
    }
    if let nestedIssue = elements.lazy.compactMap(\.serializationIssue).first {
      return nestedIssue
    }
    guard elements.first != nil || Self.defaultValue(for: elementSort) != nil else {
      return "SMT array constants cannot synthesize a default \(elementSort.description) value"
    }
    return nil
  }

  static func arrayDescription(_ elements: [Self], elementSort explicitSort: SMTSort?) -> String {
    guard let elementSort = explicitSort ?? commonSort(of: elements),
      elements.allSatisfy({ $0.matches(elementSort) }),
      elements.allSatisfy({ $0.serializationIssue == nil }),
      let defaultValue = elements.first ?? defaultValue(for: elementSort)
    else {
      return "|unsupported SMT array constant|"
    }

    let arraySort = SMTSort.array(.int, elementSort).description
    let constantArray = "((as const \(arraySort)) \(defaultValue.description))"
    return elements.enumerated().reduce(constantArray) { array, entry in
      "(store \(array) \(entry.offset) \(entry.element.description))"
    }
  }

  private static func commonSort(of values: [Self]) -> SMTSort? {
    guard let firstSort = values.first?.inferredSort,
      values.dropFirst().allSatisfy({ $0.matches(firstSort) })
    else {
      return nil
    }
    return firstSort
  }

  private var inferredSort: SMTSort? {
    switch self {
    case .bool: return .bool
    case .int: return .int
    case .real: return .real
    case .string: return .string
    case .bitVector(_, let width): return .bitVector(width)

    case .array(let elements, let explicitSort):
      guard let elementSort = explicitSort ?? Self.commonSort(of: elements) else { return nil }
      return .array(.int, elementSort)
    }
  }

  private func matches(_ sort: SMTSort) -> Bool {
    guard let inferredSort else { return false }
    return inferredSort.matches(sort)
  }

  private static func defaultValue(for sort: SMTSort) -> Self? {
    switch sort {
    case .bool: return .bool(false)
    case .int: return .int(0)
    case .real: return .real(0)
    case .string: return .string("")
    case .bitVector(let width): return .bitVector(0, width: width)

    case .array(let index, let element) where index.matches(.int):
      return .array([], elementSort: element)

    case .array, .uninterpreted, .custom:
      return nil
    }
  }
}

extension SMTSort {
  fileprivate func matches(_ other: Self) -> Bool {
    switch (self, other) {
    case (.bool, .bool), (.int, .int), (.real, .real), (.string, .string):
      return true

    case (.bitVector(let lhs), .bitVector(let rhs)):
      return lhs == rhs

    case (.array(let lhsIndex, let lhsElement), .array(let rhsIndex, let rhsElement)):
      return lhsIndex.matches(rhsIndex) && lhsElement.matches(rhsElement)

    case (.uninterpreted(let lhs), .uninterpreted(let rhs)):
      return lhs == rhs

    case (.custom(let lhsName, let lhsParams), .custom(let rhsName, let rhsParams)):
      return lhsName == rhsName && lhsParams.count == rhsParams.count
        && zip(lhsParams, rhsParams).allSatisfy { pair in pair.0.matches(pair.1) }

    default:
      return false
    }
  }
}

extension SMTExpression {
  var serializationIssue: String? {
    switch self {
    case .variable:
      return nil

    case .constant(let value):
      return value.serializationIssue

    case .function(_, let arguments):
      return arguments.lazy.compactMap(\.serializationIssue).first

    case .binary(_, let lhs, let rhs):
      return lhs.serializationIssue ?? rhs.serializationIssue

    case .unary(_, let operand):
      return operand.serializationIssue

    case .quantified(_, _, let body):
      return body.serializationIssue

    case .let_(let bindings, let body):
      return bindings.lazy.compactMap { $0.1.serializationIssue }.first
        ?? body.serializationIssue
    }
  }
}

extension SMTConstraint {
  var serializationIssue: String? {
    assertions.lazy.compactMap(\.serializationIssue).first ?? expression.serializationIssue
  }
}
