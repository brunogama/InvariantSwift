import Foundation

private enum InvariantComparison: String, CaseIterable {
  case greaterThanOrEqual = ">="
  case lessThanOrEqual = "<="
  case equal = "=="
  case notEqual = "!="
  case greaterThan = ">"
  case lessThan = "<"

  func evaluate(_ lhs: InvariantOperandValue, _ rhs: InvariantOperandValue) -> Bool? {
    switch self {
    case .equal:
      return lhs.isEqual(to: rhs)

    case .notEqual:
      return !lhs.isEqual(to: rhs)

    case .greaterThanOrEqual:
      return lhs.compareNumber(to: rhs, using: >=)

    case .lessThanOrEqual:
      return lhs.compareNumber(to: rhs, using: <=)

    case .greaterThan:
      return lhs.compareNumber(to: rhs, using: >)

    case .lessThan:
      return lhs.compareNumber(to: rhs, using: <)
    }
  }
}

private enum InvariantOperandValue: Equatable {
  case number(Double)
  case string(String)
  case boolean(Bool)
  case array([StateValue])
  case dictionary([String: StateValue])
  case null

  init(_ value: StateValue) {
    switch value {
    case .integer(let value): self = .number(Double(value))
    case .double(let value): self = .number(value)
    case .string(let value): self = .string(value)
    case .boolean(let value): self = .boolean(value)
    case .array(let value): self = .array(value)
    case .dictionary(let value): self = .dictionary(value)
    case .null: self = .null
    }
  }

  func isEqual(to other: Self) -> Bool {
    if case .number(let lhs) = self, case .number(let rhs) = other {
      if lhs == rhs { return true }
      guard lhs.isFinite, rhs.isFinite else { return false }
      return abs(lhs - rhs) < 0.0001
    }
    return self == other
  }

  func compareNumber(to other: Self, using comparison: (Double, Double) -> Bool) -> Bool? {
    guard case .number(let lhs) = self, case .number(let rhs) = other else {
      return nil
    }
    return comparison(lhs, rhs)
  }

  func member(_ name: Substring) -> Self? {
    switch (self, name) {
    case (.array(let values), "count"), (.array(let values), "length"),
      (.array(let values), "size"):
      return .number(Double(values.count))

    case (.dictionary(let values), "count"), (.dictionary(let values), "size"):
      return .number(Double(values.count))

    case (.dictionary(let values), _):
      return values[String(name)].map(Self.init)

    case (.string(let value), "count"), (.string(let value), "length"):
      return .number(Double(value.count))

    default:
      return nil
    }
  }
}

struct TracePredicate {
  private let lhs: String
  private let comparison: InvariantComparison
  private let rhs: String

  static func parse(_ source: String) -> Self? {
    for comparison in InvariantComparison.allCases {
      guard let range = source.range(of: comparison.rawValue) else { continue }
      let lhs = source[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
      let rhs = source[range.upperBound...].trimmingCharacters(in: .whitespaces)
      guard !lhs.isEmpty, !rhs.isEmpty else { return nil }
      return Self(lhs: lhs, comparison: comparison, rhs: rhs)
    }
    return nil
  }

  func evaluate(on trace: ExecutionTrace) -> Bool? {
    if isTraceScoped(lhs) || isTraceScoped(rhs) {
      guard let lhsValue = value(for: lhs, on: trace),
        let rhsValue = value(for: rhs, on: trace)
      else {
        return nil
      }
      return comparison.evaluate(lhsValue, rhsValue)
    }

    var didEvaluate = false
    for state in trace.allStates {
      guard let lhsValue = value(for: lhs, in: state),
        let rhsValue = value(for: rhs, in: state),
        let result = comparison.evaluate(lhsValue, rhsValue)
      else {
        continue
      }
      didEvaluate = true
      if !result { return false }
    }
    return didEvaluate ? true : nil
  }

  private func isTraceScoped(_ operand: String) -> Bool {
    operand == "input" || operand == "output" || operand == "result"
      || operand.hasPrefix("input.") || operand.hasPrefix("output.")
  }

  private func value(for operand: String, on trace: ExecutionTrace) -> InvariantOperandValue? {
    if let literal = literalValue(operand) { return literal }
    if operand == "result" {
      return trace.output.returnValue.map(InvariantOperandValue.init) ?? .null
    }

    let scopes = [("input", trace.input), ("output", trace.output)]
    for (name, state) in scopes where operand == name || operand.hasPrefix("\(name).") {
      if operand == name {
        return state.returnValue.map(InvariantOperandValue.init) ?? .null
      }
      let path = String(operand.dropFirst(name.count + 1))
      if let stateValue = value(for: path, in: state) { return stateValue }
      guard var resolved = state.returnValue.map(InvariantOperandValue.init) else { return nil }
      for component in path.split(separator: ".") {
        guard let member = resolved.member(component) else { return nil }
        resolved = member
      }
      return resolved
    }
    return value(for: operand, in: trace.output)
  }

  private func value(for operand: String, in state: ExecutionState) -> InvariantOperandValue? {
    if let literal = literalValue(operand) { return literal }
    if operand == "result" {
      return state.returnValue.map(InvariantOperandValue.init) ?? .null
    }
    if let value = state.variables[operand] { return InvariantOperandValue(value) }
    if let value = state.properties[operand] { return .number(value) }

    var components = operand.split(separator: ".")
    guard let root = components.first else { return nil }
    components.removeFirst()
    guard var resolved = state.variables[String(root)].map(InvariantOperandValue.init) else {
      return nil
    }
    for component in components {
      guard let member = resolved.member(component) else { return nil }
      resolved = member
    }
    return resolved
  }

  private func literalValue(_ operand: String) -> InvariantOperandValue? {
    if operand == "null" { return .null }
    if operand == "true" { return .boolean(true) }
    if operand == "false" { return .boolean(false) }
    if let value = Double(operand) { return .number(value) }
    guard operand.count >= 2, operand.first == "\"", operand.last == "\"" else {
      return nil
    }
    return .string(String(operand.dropFirst().dropLast()))
  }
}
