import Foundation

/// A parsed SMT-LIB s-expression.
///
/// Solver models are s-expressions, not line-oriented text: `z3` wraps
/// `(get-model)` output in an outer list, breaks long definitions across
/// lines, and prints negative values as the application `(- 5)`. Parsing the
/// token stream is the only way to read those forms correctly.
enum SMTSExpression: Equatable {
  case atom(String)
  case list([Self])

  /// Parses every top-level expression in `text`.
  ///
  /// Malformed trailing input is discarded rather than failing the whole
  /// parse, because a solver can be terminated mid-write.
  static func parseAll(_ text: String) -> [Self] {
    var tokens = Tokenizer(text)
    var expressions: [Self] = []
    while let expression = parse(&tokens) {
      expressions.append(expression)
    }
    return expressions
  }

  private static func parse(_ tokens: inout Tokenizer) -> Self? {
    guard let token = tokens.next() else { return nil }
    switch token {
    case .open:
      return parseList(&tokens)

    case .close:
      return nil

    case .atom(let text):
      return .atom(text)
    }
  }

  private static func parseList(_ tokens: inout Tokenizer) -> Self? {
    var elements: [Self] = []
    while true {
      switch tokens.peek() {
      case .none:
        // Unterminated list: the writer was cut off.
        return nil

      case .close:
        _ = tokens.next()
        return .list(elements)

      default:
        guard let element = parse(&tokens) else { return nil }
        elements.append(element)
      }
    }
  }
}

extension SMTSExpression {
  /// The elements of a list expression, or `nil` for an atom.
  var elements: [Self]? {
    guard case .list(let elements) = self else { return nil }
    return elements
  }

  /// The text of an atom expression, or `nil` for a list.
  var text: String? {
    guard case .atom(let text) = self else { return nil }
    return text
  }
}

/// Splits SMT-LIB text into parentheses, quoted symbols, strings and atoms.
private struct Tokenizer {
  enum Token: Equatable {
    case open
    case close
    case atom(String)
  }

  private let characters: [Character]
  private var index: Int
  private var lookahead: Token?

  init(_ text: String) {
    characters = Array(text)
    index = 0
  }

  mutating func peek() -> Token? {
    if lookahead == nil { lookahead = scan() }
    return lookahead
  }

  mutating func next() -> Token? {
    if let token = lookahead {
      lookahead = nil
      return token
    }
    return scan()
  }

  private mutating func scan() -> Token? {
    skipIgnored()
    guard index < characters.count else { return nil }
    let character = characters[index]
    switch character {
    case "(":
      index += 1
      return .open

    case ")":
      index += 1
      return .close

    case "|":
      return .atom(scanDelimited(terminator: "|"))

    case "\"":
      return .atom(scanDelimited(terminator: "\""))

    default:
      return .atom(scanBareAtom())
    }
  }

  private mutating func skipIgnored() {
    while index < characters.count {
      let character = characters[index]
      if character.isWhitespace {
        index += 1
      } else if character == ";" {
        while index < characters.count, !characters[index].isNewline { index += 1 }
      } else {
        return
      }
    }
  }

  /// Reads a `|quoted symbol|` or `"string literal"`, returning its contents.
  private mutating func scanDelimited(terminator: Character) -> String {
    index += 1
    var text = ""
    while index < characters.count, characters[index] != terminator {
      text.append(characters[index])
      index += 1
    }
    if index < characters.count { index += 1 }
    return text
  }

  private mutating func scanBareAtom() -> String {
    var text = ""
    while index < characters.count {
      let character = characters[index]
      guard !character.isWhitespace, character != "(", character != ")" else { break }
      text.append(character)
      index += 1
    }
    return text
  }
}
