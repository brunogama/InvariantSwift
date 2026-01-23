import Foundation
import InvariantSwiftCore

// MARK: - Pretty-Printing and Diff System for Counterexamples

// swiftlint:disable:next orphaned_doc_comment
/// **Pretty-Printing Infrastructure**
///
/// Advanced pretty-printing system for test values, counterexamples, and diffs.
/// Provides human-readable output for debugging property test failures with:
/// - Structured formatting with syntax highlighting
/// - Diff visualization for before/after comparisons
/// - Smart truncation and folding for large structures
/// - Cross-platform terminal and IDE integration
///
/// **Mathematical Foundation:**
/// Based on Wadler's "A Prettier Printer" algorithm with extensions for:
/// - Associative tree formatting
/// - Context-sensitive layout choices
/// - Incremental rendering for streaming output
///
/// **External References:**
/// - [Wadler's Pretty Printer](https://homepages.inf.ed.ac.uk/wadler/papers/prettier/prettier.pdf)
/// - [Leijen's PPrint Library](https://citeseerx.ist.psu.edu/document?repid=rep1&type=pdf&doi=d31e8e0605edbe89a7d6b8cc7c7f95ab73b9c3e4)
/// - [Tree-sitter for Syntax Highlighting](https://tree-sitter.github.io/tree-sitter/)

// MARK: - Object Tracking for Cycle Detection

/// Tracks object references to detect cycles during pretty-printing.
///
/// When printing class instances or reference types, circular references can cause
/// infinite recursion. `ObjectTracker` detects these cycles and displays them as
/// back-references (e.g., "↩︎ (see #1)") instead of recursing infinitely.
///
/// **Thread Safety:** Designed to be passed by `inout` through the print call stack.
/// Not shared across concurrent operations.
///
/// **Performance:** O(1) lookup and insertion using `ObjectIdentifier` hashing.
public struct ObjectTracker: Sendable {
  /// Maps object identifiers to their assigned reference IDs
  private var idMapping: [ObjectIdentifier: Int] = [:]

  /// Set of objects currently being visited (for cycle detection)
  private var visitedIDs: Set<ObjectIdentifier> = []

  /// Next available reference ID
  private var nextID: Int = 1

  /// Initialize an empty object tracker
  public init() {}

  /// Result of visiting an object
  public enum VisitResult: Sendable {
    /// First time visiting this object; assigned the given ID
    case firstVisit(assignedID: Int)
    /// Object was already visited; this is a cycle back to the given ID
    case cycleDetected(referenceID: Int)
  }

  /// Begin visiting an object. Returns whether this is a first visit or a cycle.
  ///
  /// - Parameter object: The object to visit
  /// - Returns: `.firstVisit` with assigned ID, or `.cycleDetected` with existing ID
  public mutating func beginVisit(_ object: AnyObject) -> VisitResult {
    let id = ObjectIdentifier(object)

    // Check if we're currently visiting this object (cycle)
    if visitedIDs.contains(id) {
      let refID = idMapping[id] ?? 0
      return .cycleDetected(referenceID: refID)
    }

    // First visit - assign an ID and mark as visiting
    visitedIDs.insert(id)
    let assignedID = nextID
    idMapping[id] = assignedID
    nextID += 1
    return .firstVisit(assignedID: assignedID)
  }

  /// End visiting an object. Call this after fully printing the object.
  ///
  /// - Parameter object: The object that was being visited
  public mutating func endVisit(_ object: AnyObject) {
    let id = ObjectIdentifier(object)
    visitedIDs.remove(id)
  }

  /// Check if an object has been seen before (without starting a visit)
  ///
  /// - Parameter object: The object to check
  /// - Returns: The reference ID if seen before, nil otherwise
  public func referenceID(for object: AnyObject) -> Int? {
    idMapping[ObjectIdentifier(object)]
  }

  /// Format a cycle reference marker
  ///
  /// - Parameter referenceID: The ID of the referenced object
  /// - Returns: A formatted string like "↩︎ (see #1)"
  public static func cycleMarker(referenceID: Int) -> String {
    "↩︎ (see #\(referenceID))"
  }

  /// Format an object ID marker for first occurrence
  ///
  /// - Parameter assignedID: The assigned ID
  /// - Returns: A formatted string like "#1"
  public static func idMarker(assignedID: Int) -> String {
    "#\(assignedID)"
  }
}

// MARK: - Diff Format

/// Format options for diff output.
///
/// Controls the visual markers used to indicate additions, removals, and unchanged lines
/// in diff output. Two presets are provided:
/// - `.default`: ASCII characters for terminal compatibility
/// - `.proportional`: Unicode characters for better Xcode/IDE display
///
/// **Example Output (default):**
/// ```
/// - age: 30
/// + age: 31
/// ```
///
/// **Example Output (proportional):**
/// ```
/// − age: 30
/// + age: 31
/// ```
public struct DiffFormat: Sendable, Equatable {
  /// Marker for removed/old values (e.g., "-" or "−")
  public let first: String

  /// Marker for added/new values (e.g., "+")
  public let second: String

  /// Marker for unchanged values (space or figure space)
  public let unchanged: String

  /// Initialize a custom diff format
  ///
  /// - Parameters:
  ///   - first: Marker for removed values
  ///   - second: Marker for added values
  ///   - unchanged: Marker for unchanged values
  public init(first: String, second: String, unchanged: String) {
    self.first = first
    self.second = second
    self.unchanged = unchanged
  }

  /// Default ASCII format for terminal output
  ///
  /// Uses `-` for removals, `+` for additions, and space for unchanged.
  public static let `default` = Self(
    first: "-",
    second: "+",
    unchanged: " "
  )

  /// Proportional Unicode format for Xcode/IDE output
  ///
  /// Uses Unicode minus sign (U+2212) for removals, `+` for additions,
  /// and figure space (U+2007) for unchanged to maintain alignment.
  public static let proportional = Self(
    first: "\u{2212}",  // MINUS SIGN
    second: "+",
    unchanged: "\u{2007}"  // FIGURE SPACE
  )
}

// MARK: - Core Pretty-Printing Types

/// **Document representation for pretty-printing**
public indirect enum Doc: Sendable {
  case empty
  case text(String)
  case line
  case concat(Self, Self)
  case nest(Int, Self)
  case union(Self, Self)  // Choice between layouts
  case group(Self)  // Attempt to fit on one line
  case align(Self)  // Align subsequent lines
  case hang(Int, Self)  // Hanging indent
  case indent(Int, Self)  // Block indent

  // Color and styling
  case colored(ConsoleColor, Self)
  case styled(ConsoleStyle, Self)

  // Smart constructors
  public static let space = text(" ")
  public static let comma = text(",")
  public static let semicolon = text(";")
  public static let lbrace = text("{")
  public static let rbrace = text("}")
  public static let lbracket = text("[")
  public static let rbracket = text("]")
  public static let lparen = text("(")
  public static let rparen = text(")")
}

/// **Console colors for terminal output**
public enum ConsoleColor: String, CaseIterable, Sendable {
  case black = "30"
  case red = "31"
  case green = "32"
  case yellow = "33"
  case blue = "34"
  case magenta = "35"
  case cyan = "36"
  case white = "37"
  case gray = "90"
  case brightRed = "91"
  case brightGreen = "92"
  case brightYellow = "93"
  case brightBlue = "94"
  case brightMagenta = "95"
  case brightCyan = "96"
  case brightWhite = "97"
}

/// **Console styling options**
public enum ConsoleStyle: String, CaseIterable, Sendable {
  case bold = "1"
  case dim = "2"
  case italic = "3"
  case underline = "4"
  case strikethrough = "9"
}

/// **Pretty-printing configuration**
public struct PrettyConfig: Sendable {
  /// Page width for layout decisions
  public let pageWidth: Int

  /// Ribbon width (text before line breaks)
  public let ribbonWidth: Int

  /// Enable color output
  public let enableColors: Bool

  /// Maximum depth for nested structures
  public let maxDepth: Int

  /// Maximum array/collection length to show
  public let maxLength: Int

  /// Indentation size
  public let indentSize: Int

  public init(
    pageWidth: Int = 80,
    ribbonWidth: Int = 60,
    enableColors: Bool = true,
    maxDepth: Int = 10,
    maxLength: Int = 100,
    indentSize: Int = 2
  ) {
    self.pageWidth = pageWidth
    self.ribbonWidth = ribbonWidth
    self.enableColors = enableColors
    self.maxDepth = maxDepth
    self.maxLength = maxLength
    self.indentSize = indentSize
  }

  /// Configuration optimized for test output
  public static let testOutput = Self(
    pageWidth: 100,
    ribbonWidth: 80,
    enableColors: ProcessInfo.processInfo.environment["NO_COLOR"] == nil,
    maxDepth: 8,
    maxLength: 50,
    indentSize: 2
  )

  /// Configuration for compact output
  public static let compact = Self(
    pageWidth: 120,
    ribbonWidth: 100,
    enableColors: false,
    maxDepth: 5,
    maxLength: 20,
    indentSize: 1
  )
}

// MARK: - Pretty-Printable Protocol

/// **Protocol for types that can be pretty-printed**
public protocol PrettyPrintable {
  /// Convert the value to a pretty-printable document
  /// - Parameters:
  ///   - config: Pretty-printing configuration
  ///   - depth: Current nesting depth
  /// - Returns: Document representation
  func prettyDoc(config: PrettyConfig, depth: Int) -> Doc
}

// MARK: - Default Implementations

extension String: PrettyPrintable {
  public func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    if count > 50 {
      let truncated = String(prefix(47)) + "..."
      return .colored(.yellow, .text("\"\(truncated)\""))
    }
    return .colored(.green, .text("\"\(self)\""))
  }
}

extension Int: PrettyPrintable {
  public func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    .colored(.cyan, .text(String(self)))
  }
}

extension Double: PrettyPrintable {
  public func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    .colored(.cyan, .text(String(self)))
  }
}

extension Bool: PrettyPrintable {
  public func prettyDoc(config: PrettyConfig, depth: Int) -> Doc {
    .colored(.magenta, .text(String(self)))
  }
}

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

// MARK: - Document Combinators

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

// MARK: - Diff System

/// **Diff representation for comparing values**
public enum DiffResult<T>: Sendable where T: Sendable {
  case identical(T)
  case different(old: T, new: T)
  case added(T)
  case removed(T)
}

/// **Structured diff for complex types**
public indirect enum StructuredDiff: Sendable {
  case unchanged(String)
  case changed(old: String, new: String)
  case added(String)
  case removed(String)
  case nested(key: String, diff: Self)
  case collection([Self])
  case collapsed(unchangedCount: Int)

  /// Render the diff to a string with the given format
  public func render(format: DiffFormat = .default, indent: Int = 0) -> String {
    let indentStr = String(repeating: "  ", count: indent)

    switch self {
    case .unchanged(let value):
      return "\(indentStr)\(format.unchanged) \(value)"

    case .changed(let old, let new):
      return """
        \(indentStr)\(format.first) \(old)
        \(indentStr)\(format.second) \(new)
        """

    case .added(let value):
      return "\(indentStr)\(format.second) \(value)"

    case .removed(let value):
      return "\(indentStr)\(format.first) \(value)"

    case .nested(let key, let diff):
      return "\(indentStr)\(key):\n\(diff.render(format: format, indent: indent + 1))"

    case .collection(let diffs):
      return diffs.map { $0.render(format: format, indent: indent) }.joined(separator: "\n")

    case .collapsed(let count):
      return "\(indentStr)\(format.unchanged) ... (\(count) unchanged)"
    }
  }
}

/// **Protocol for types that can be diffed**
public protocol Diffable {
  /// Create a structured diff between two values
  /// - Parameter other: The other value to compare against
  /// - Returns: Structured diff representation
  func diff(other: Self) -> StructuredDiff
}

// MARK: - Diff Implementations

extension String: Diffable {
  public func diff(other: String) -> StructuredDiff {
    if self == other {
      return .unchanged(self)
    } else {
      return .changed(old: self, new: other)
    }
  }
}

extension Array: Diffable where Element: Diffable & Equatable {
  public func diff(other: [Element]) -> StructuredDiff {
    diff(other: other, collapseUnchanged: true, collapseThreshold: 2)
  }

  public func diff(
    other: [Element],
    collapseUnchanged: Bool,
    collapseThreshold: Int = 2
  ) -> StructuredDiff {
    var diffs: [StructuredDiff] = []
    var unchangedRun: [StructuredDiff] = []

    func flushUnchanged() {
      guard !unchangedRun.isEmpty else { return }
      if collapseUnchanged && unchangedRun.count > collapseThreshold {
        diffs.append(.collapsed(unchangedCount: unchangedRun.count))
      } else {
        diffs.append(contentsOf: unchangedRun)
      }
      unchangedRun.removeAll()
    }

    let maxIndex = Swift.max(count, other.count)
    for i in 0..<maxIndex {
      let hasOld = i < count
      let hasNew = i < other.count

      switch (hasOld, hasNew) {
      case (true, true):
        let oldElem = self[i]
        let newElem = other[i]
        if oldElem == newElem {
          unchangedRun.append(.unchanged("\(oldElem)"))
        } else {
          flushUnchanged()
          diffs.append(oldElem.diff(other: newElem))
        }

      case (true, false):
        flushUnchanged()
        diffs.append(.removed("\(self[i])"))

      case (false, true):
        flushUnchanged()
        diffs.append(.added("\(other[i])"))

      case (false, false):
        break
      }
    }

    flushUnchanged()
    return .collection(diffs)
  }
}

// MARK: - Pretty-Printing Engine

/// **Core pretty-printing engine**
public struct PrettyPrinter: Sendable {
  public let config: PrettyConfig

  public init(config: PrettyConfig = .testOutput) {
    self.config = config
  }

  /// **Render a document to a string**
  /// - Parameter doc: Document to render
  /// - Returns: Formatted string
  public func render(_ doc: Doc) -> String {
    layout(best(width: config.pageWidth, doc))
  }

  /// **Pretty-print any printable value**
  /// - Parameter value: Value to print
  /// - Returns: Formatted string
  public func print<T: PrettyPrintable>(_ value: T) -> String {
    render(value.prettyDoc(config: config, depth: 0))
  }

  /// **Create a diff visualization**
  /// - Parameters:
  ///   - title: Title for the diff
  ///   - old: Original value
  ///   - new: New value
  ///   - format: Diff format to use (default: `.default`)
  /// - Returns: Formatted diff string
  public func diff<T: PrettyPrintable & Diffable>(
    title: String,
    old: T,
    new: T,
    format: DiffFormat = .default
  ) -> String {
    let structuredDiff = old.diff(other: new)
    let diffBody = structuredDiff.render(format: format, indent: 1)

    let diffDoc = Doc.concat([
      .styled(.bold, .text("Diff: \(title)")),
      .line,
      .text(diffBody),
      .line,
      .line,
      .colored(.gray, .text("(First: \(format.first), Second: \(format.second))")),
    ])

    return render(diffDoc)
  }

  /// **Create a diff visualization for any Equatable types**
  /// - Parameters:
  ///   - title: Title for the diff
  ///   - old: Original value
  ///   - new: New value
  ///   - format: Diff format to use (default: `.default`)
  /// - Returns: Formatted diff string, or nil if values are equal
  public func diffAny<T: Equatable>(
    title: String,
    old: T,
    new: T,
    format: DiffFormat = .default
  ) -> String? {
    guard old != new else { return nil }

    // swiftlint:disable:next no_print
    let oldStr = (old as? PrettyPrintable).map { print($0) } ?? "\(old)"
    // swiftlint:disable:next no_print
    let newStr = (new as? PrettyPrintable).map { print($0) } ?? "\(new)"

    let diffDoc = Doc.concat([
      .styled(.bold, .text("Diff: \(title)")),
      .line,
      .colored(.red, .text("\(format.first) \(oldStr)")),
      .line,
      .colored(.green, .text("\(format.second) \(newStr)")),
      .line,
      .line,
      .colored(.gray, .text("(First: \(format.first), Second: \(format.second))")),
    ])

    return render(diffDoc)
  }

  // MARK: - Layout Algorithm

  private indirect enum SimpleDoc {
    case empty
    case text(String, Self)
    case line(Int, Self)  // Indentation level
  }

  private func best(width: Int, _ doc: Doc) -> SimpleDoc {
    be(width: width, col: 0, docs: [(0, doc)])
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func be(width: Int, col: Int, docs: [(Int, Doc)]) -> SimpleDoc {
    guard let (indent, doc) = docs.first else {
      return .empty
    }

    let remaining = Array(docs.dropFirst())

    switch doc {
    case .empty:
      return be(width: width, col: col, docs: remaining)

    case .text(let s):
      return .text(s, be(width: width, col: col + s.count, docs: remaining))

    case .line:
      return .line(indent, be(width: width, col: indent, docs: remaining))

    case .concat(let x, let y):
      return be(width: width, col: col, docs: [(indent, x), (indent, y)] + remaining)

    case .nest(let j, let x):
      return be(width: width, col: col, docs: [(indent + j, x)] + remaining)

    case .union(let x, let y):
      // Choose better layout
      let xResult = be(width: width, col: col, docs: [(indent, x)] + remaining)
      if fits(width - col, xResult) {
        return xResult
      } else {
        return be(width: width, col: col, docs: [(indent, y)] + remaining)
      }

    case .group(let x):
      return be(width: width, col: col, docs: [(indent, .union(flatten(x), x))] + remaining)

    case .align(let x):
      return be(width: width, col: col, docs: [(col, x)] + remaining)

    case .hang(let j, let x):
      return be(width: width, col: col, docs: [(indent + j, x)] + remaining)

    case .indent(let j, let x):
      return be(width: width, col: col, docs: [(indent + j, x)] + remaining)

    case .colored(_, let x), .styled(_, let x):
      return be(width: width, col: col, docs: [(indent, x)] + remaining)
    }
  }

  private func fits(_ width: Int, _ doc: SimpleDoc) -> Bool {
    guard width >= 0 else { return false }

    switch doc {
    case .empty:
      return true

    case .text(let s, let x):
      return fits(width - s.count, x)

    case .line:
      return true
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func flatten(_ doc: Doc) -> Doc {
    switch doc {
    case .concat(let x, let y):
      return .concat(flatten(x), flatten(y))

    case .nest(_, let x):
      return flatten(x)

    case .line:
      return .space

    case .union(let x, _):
      return flatten(x)

    case .group(let x):
      return flatten(x)

    case .align(let x):
      return flatten(x)

    case .hang(_, let x):
      return flatten(x)

    case .indent(_, let x):
      return flatten(x)

    case .colored(let color, let x):
      return .colored(color, flatten(x))

    case .styled(let style, let x):
      return .styled(style, flatten(x))

    default:
      return doc
    }
  }

  private func layout(_ doc: SimpleDoc) -> String {
    switch doc {
    case .empty:
      return ""

    case .text(let s, let x):
      return applyFormatting(s) + layout(x)

    case .line(let indent, let x):
      return "\n" + String(repeating: " ", count: indent) + layout(x)
    }
  }

  private func applyFormatting(_ text: String) -> String {
    guard config.enableColors else { return text }

    // ANSI escape codes would be applied here
    // For now, return text as-is
    return text
  }
}

// MARK: - Global Pretty-Printing Functions

/// **Global pretty-print function**
/// - Parameter value: Value to print
/// - Returns: Pretty-printed string
public func prettyPrint<T: PrettyPrintable>(_ value: T) -> String {
  // swiftlint:disable:next no_print
  PrettyPrinter().print(value)
}

/// **Global diff function**
/// - Parameters:
///   - title: Title for the diff
///   - old: Original value
///   - new: New value
///   - format: Diff format (default: `.default`)
/// - Returns: Diff visualization
public func prettyDiff<T: PrettyPrintable & Diffable>(
  _ title: String,
  old: T,
  new: T,
  format: DiffFormat = .default
) -> String {
  PrettyPrinter().diff(title: title, old: old, new: new, format: format)
}

// MARK: - Integration with Property Testing

extension PropertyResult {
  /// **Pretty-print the property result**
  /// - Parameter config: Pretty-printing configuration
  /// - Returns: Formatted result description
  public func prettyDescription(
    config: PrettyConfig = .testOutput
  ) -> String {
    let printer = PrettyPrinter(config: config)

    switch self {
    case .success(let iterations):
      return printer.render(
        .concat(
          .colored(.green, .styled(.bold, .text("✓ Property passed"))),
          .concat(.text(" after "), .colored(.cyan, .text("\(iterations) iterations")))
        )
      )

    case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
      let counterDoc =
        (counterexample as? PrettyPrintable)?.prettyDoc(config: config, depth: 0)
        ?? .text("\(counterexample)")
      let shrunkDoc =
        (shrunk as? PrettyPrintable)?.prettyDoc(config: config, depth: 0) ?? .text("\(shrunk)")

      return printer.render(
        Doc.concat([
          .colored(.red, .styled(.bold, .text("Property failed"))),
          .text(" after "),
          .colored(.cyan, .text("\(iterations) iterations")),
          .text(" (\(reason))"),
          .line,
          .line,
          .colored(.red, .text("Counterexample:")),
          .line,
          .indent(2, counterDoc),
          .line,
          .line,
          .colored(.yellow, .text("Minimal counterexample:")),
          .line,
          .indent(2, shrunkDoc),
          .line,
          .line,
          .colored(.cyan, .text("Seed: \(seed.rawValue)")),
        ])
      )

    case .gaveUp:
      return printer.render(
        .colored(.yellow, .styled(.bold, .text("⚠ Property gave up (too many discarded cases)")))
      )
    }
  }
}

// MARK: - Histogram Formatting

/// Format a histogram of values for console output.
///
/// Creates an ASCII bar chart representation of value distributions.
///
/// - Parameters:
///   - category: Category name for the histogram
///   - values: Dictionary of value -> count
///   - maxBars: Maximum bar width (default: 40)
/// - Returns: Formatted histogram string
public func formatHistogram(
  category: String,
  values: [String: Int],
  maxBars: Int = 40
) -> String {
  guard !values.isEmpty else { return "  \(category): (no values)" }

  let total = values.values.reduce(0, +)
  let maxCount = values.values.max() ?? 1

  // Sort by count descending, then alphabetically
  let sorted = values.sorted { first, second in
    if first.value != second.value {
      return first.value > second.value
    }
    return first.key < second.key
  }

  let maxKeyLength = sorted.map(\.key.count).max() ?? 0

  var lines: [String] = []
  lines.append("  \(category):")

  for (key, count) in sorted {
    let percentage = total > 0 ? (Double(count) / Double(total)) * 100.0 : 0
    let barLength = maxCount > 0 ? Int(Double(count) / Double(maxCount) * Double(maxBars)) : 0
    let bar = String(repeating: "=", count: max(1, barLength))

    let paddedKey = key.padding(toLength: maxKeyLength, withPad: " ", startingAt: 0)
    let percentStr = String(format: "%5.1f%%", percentage)
    let countStr = String(format: "%4d", count)

    lines.append("    \(paddedKey) \(bar) \(countStr) (\(percentStr))")
  }

  return lines.joined(separator: "\n")
}

// MARK: - Table Formatting

/// Format a classification table for console output.
///
/// - Parameters:
///   - title: Table title
///   - categories: Dictionary of category -> (label -> stats)
/// - Returns: Formatted table string
public func formatClassificationTable(
  title: String,
  categories: [String: [String: ClassificationReport.LabelStats]]
) -> String {
  guard !categories.isEmpty else { return "" }

  var lines: [String] = []
  lines.append("")
  lines.append("\(title)")
  lines.append(String(repeating: "-", count: 50))

  for category in categories.keys.sorted() {
    guard let labels = categories[category] else { continue }

    lines.append("")
    lines.append("Category: \(category)")

    // Sort by percentage descending
    let sorted = labels.sorted { $0.value.percentage > $1.value.percentage }
    let maxLabelLength = sorted.map(\.key.count).max() ?? 0

    for (label, stats) in sorted {
      let paddedLabel = label.padding(toLength: maxLabelLength, withPad: " ", startingAt: 0)
      let percentStr = String(format: "%.1f%%", stats.percentage)
      lines.append("  \(paddedLabel): \(stats.count) (\(percentStr))")
    }
  }

  return lines.joined(separator: "\n")
}

// MARK: - Failure Formatting

/// Format a property failure with custom messages.
///
/// - Parameters:
///   - result: The failure result
///   - customMessages: Custom messages computed from counterexample closures
///   - classification: Classification report (optional)
/// - Returns: Formatted failure string
public func formatPropertyFailure<T>(
  result: PropertyResult<T>,
  customMessages: [String] = [],
  classification: ClassificationReport? = nil
) -> String where T: CustomStringConvertible {
  guard case .failure(let counterexample, let iterations, let shrunk, let reason, let seed) = result
  else {
    return ""
  }

  var lines: [String] = []

  lines.append("*** Failed! \(reason) after \(iterations) test(s).")
  lines.append("")

  // Custom messages first (if any)
  if !customMessages.isEmpty {
    for message in customMessages {
      lines.append(message)
    }
    lines.append("")
  }

  // Counterexample details
  lines.append("Counterexample:")
  lines.append("  Original: \(counterexample)")
  lines.append("  Shrunk:   \(shrunk)")
  lines.append("")

  // Reproduction info
  lines.append("Reproduce with seed: \(seed.rawValue)")

  // Classification report (if any)
  if let report = classification,
    !report.labelDistribution.isEmpty || !report.coverageResults.isEmpty
  {
    lines.append("")
    lines.append(report.format())
  }

  return lines.joined(separator: "\n")
}

/// Format coverage result with status icon.
public func formatCoverageStatus(_ result: ClassificationReport.CoverageResult) -> String {
  let icon = result.met ? "+" : "x"
  let percentStr = String(format: "%.1f%%", result.percentage)
  let thresholdStr = String(format: "%.1f%%", result.threshold)
  return "\(icon) \(result.name): \(percentStr) (threshold: \(thresholdStr))"
}

/// **Helper function to separate documents**
func separatedBy(_ separator: Doc, _ docs: [Dog]) -> Doc {
  Doc.separatedBy(separator, docs)
  // swiftlint:disable:next file_length
}
