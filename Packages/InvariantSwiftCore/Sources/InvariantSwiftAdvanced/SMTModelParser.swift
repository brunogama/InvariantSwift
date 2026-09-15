import Foundation

/// Reads a solver model out of `(get-model)` output.
enum SMTModelParser {
  /// Collects every `define-fun` binding reachable from `text`.
  ///
  /// `z3` wraps the definitions in an outer list while `cvc5` prints them at
  /// the top level, so both shapes are searched.
  static func parseModel(_ text: String) -> [String: SMTValue] {
    var model: [String: SMTValue] = [:]
    for expression in SMTSExpression.parseAll(text) {
      collect(from: expression, into: &model)
    }
    return model
  }

  private static func collect(
    from expression: SMTSExpression,
    into model: inout [String: SMTValue]
  ) {
    guard let elements = expression.elements else { return }
    if let binding = parseDefinition(elements) {
      model[binding.name] = binding.value
      return
    }
    for element in elements {
      collect(from: element, into: &model)
    }
  }

  /// Parses `(define-fun name () Sort value)`.
  ///
  /// Definitions with parameters are skipped: they describe a function, not a
  /// value this model representation can hold.
  private static func parseDefinition(_ elements: [SMTSExpression]) -> SMTBinding? {
    guard
      elements.count == 5,
      elements[0].text == "define-fun",
      let name = elements[1].text,
      elements[2].elements?.isEmpty == true,
      let value = parseValue(elements[4])
    else {
      return nil
    }
    return SMTBinding(name: name, value: value)
  }

  static func parseValue(_ expression: SMTSExpression) -> SMTValue? {
    switch expression {
    case .atom(let text):
      return parseAtom(text)

    case .list(let elements):
      return parseApplication(elements)
    }
  }

  private static func parseAtom(_ text: String) -> SMTValue? {
    if text == "true" { return .bool(true) }
    if text == "false" { return .bool(false) }
    if let bitVector = parseBitVectorLiteral(text) { return bitVector }
    if let integer = Int(text) { return .int(integer) }
    if let real = Double(text) { return .real(real) }
    return nil
  }

  /// Handles the compound value forms a solver emits: `(- 5)`, `(/ 1 3)` and
  /// the indexed bit-vector literal `(_ bv12 8)`.
  private static func parseApplication(_ elements: [SMTSExpression]) -> SMTValue? {
    switch elements.first?.text {
    case "-" where elements.count == 2:
      return negate(parseValue(elements[1]))

    case "/" where elements.count == 3:
      return divide(parseValue(elements[1]), parseValue(elements[2]))

    case "_" where elements.count == 3:
      return parseIndexedBitVector(elements)

    default:
      return nil
    }
  }

  private static func negate(_ value: SMTValue?) -> SMTValue? {
    switch value {
    case .int(let integer):
      return .int(-integer)

    case .real(let real):
      return .real(-real)

    default:
      return nil
    }
  }

  private static func divide(_ numerator: SMTValue?, _ denominator: SMTValue?) -> SMTValue? {
    guard
      let numerator = numerator?.numericValue,
      let denominator = denominator?.numericValue,
      denominator != 0
    else {
      return nil
    }
    return .real(numerator / denominator)
  }

  /// Parses `#b1010` and `#xF0` bit-vector literals.
  private static func parseBitVectorLiteral(_ text: String) -> SMTValue? {
    if text.hasPrefix("#b") {
      let digits = text.dropFirst(2)
      guard !digits.isEmpty, let value = UInt64(digits, radix: 2) else { return nil }
      return .bitVector(value, width: digits.count)
    }
    if text.hasPrefix("#x") {
      let digits = text.dropFirst(2)
      guard !digits.isEmpty, let value = UInt64(digits, radix: 16) else { return nil }
      return .bitVector(value, width: digits.count * 4)
    }
    return nil
  }

  /// Parses `(_ bv12 8)`.
  private static func parseIndexedBitVector(_ elements: [SMTSExpression]) -> SMTValue? {
    guard
      let symbol = elements[1].text,
      symbol.hasPrefix("bv"),
      let value = UInt64(symbol.dropFirst(2)),
      let widthText = elements[2].text,
      let width = Int(widthText),
      width > 0
    else {
      return nil
    }
    return .bitVector(value, width: width)
  }
}

struct SMTBinding: Equatable {
  let name: String
  let value: SMTValue
}

private extension SMTValue {
  var numericValue: Double? {
    switch self {
    case .int(let integer): Double(integer)
    case .real(let real): real
    default: nil
    }
  }
}
