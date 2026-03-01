/// PrettyPrintable conformances for collection types and Doc combinators.
///
/// Provides PrettyPrintable conformances for Array, Dictionary, and Optional,
/// along with Doc combinator extensions for building pretty-printed documents.
/// Extracted from PrettyPrint.swift to keep that file under the line budget.

import Foundation
import InvariantSwiftCore

// MARK: - Collection PrettyPrintable Conformances

extension Array: PrettyPrintable where Element: PrettyPrintable {
  public func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    guard depth < config.maxDepth else {
      return .colored(.gray, .text("[...]"))
    }

    guard !isEmpty else {
      return .text("[]")
    }

    let elements = prefix(config.maxLength).map { element in
      element.prettyDoc(config: config, depth: depth + 1)
    }

    let truncated = count > config.maxLength
    let docs =
      elements + (truncated ? [.colored(.gray, .text("... \(count - config.maxLength) more"))] : [])

    return .group(
      .concat(
        .lbracket,
        .concat(
          .nest(config.indentSize, separatedBy(.concat(.comma, .space), docs)),
          .rbracket
        )
      )
    )
  }
}

extension Dictionary: PrettyPrintable where Key: PrettyPrintable, Value: PrettyPrintable {
  public func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    guard depth < config.maxDepth else {
      return .colored(.gray, .text("{...}"))
    }

    guard !isEmpty else {
      return .text("{}")
    }

    // Sort keys by string representation for deterministic output
    let sortedPairs = map { (key: $0.key, value: $0.value) }
      .sorted { "\($0.key)" < "\($1.key)" }

    let pairs = sortedPairs.prefix(config.maxLength).map { key, value in
      Doc.concat(
        key.prettyDoc(config: config, depth: depth + 1),
        .concat(.text(": "), value.prettyDoc(config: config, depth: depth + 1))
      )
    }

    let truncated = count > config.maxLength
    let docs =
      Array(pairs)
      + (truncated
        ? [.colored(.gray, .text("... \(count - config.maxLength) more"))]
        : [])

    return .group(
      .concat(
        .lbrace,
        .concat(
          .nest(config.indentSize, separatedBy(.concat(.comma, .space), docs)),
          .rbrace
        )
      )
    )
  }
}

extension Optional: PrettyPrintable where Wrapped: PrettyPrintable {
  public func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    switch self {
    case .none:
      return .colored(.gray, .text("nil"))

    case .some(let value):
      return value.prettyDoc(config: config, depth: depth)
    }
  }
}

// MARK: - Doc Combinators

extension Doc {
  /// **Concatenate documents**
  public static func concat(_ docs: [Doc]) -> Doc {
    docs.reduce(.empty) { .concat($0, $1) }
  }

  /// **Separate documents with a separator**
  public static func separatedBy(_ separator: Doc, _ docs: [Doc]) -> Doc {
    guard !docs.isEmpty else { return .empty }
    guard docs.count > 1 else { return docs[0] }

    var result = docs[0]
    for doc in docs.dropFirst() {
      result = .concat(result, .concat(separator, doc))
    }
    return result
  }

  /// **Surround document with delimiters**
  public func surrounded(by left: Doc, and right: Doc) -> Doc {
    .concat(left, .concat(self, right))
  }

  /// **Add parentheses if condition is true**
  public func parensIf(_ condition: Bool) -> Doc {
    condition ? surrounded(by: .lparen, and: .rparen) : self
  }

  /// **Apply multiple colors/styles**
  public func styled(_ styles: [ConsoleStyle]) -> Doc {
    styles.reduce(self) { doc, style in
      .styled(style, doc)
    }
  }

  /// **Apply color with fallback for non-color terminals**
  public func colorized(_ color: ConsoleColor, fallback: String = "") -> Doc {
    .colored(color, self)
  }
}
