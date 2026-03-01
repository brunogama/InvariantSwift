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

// Note: Array, Dictionary, Optional PrettyPrintable conformances and Doc combinators
// are defined in PrettyPrintExtensions.swift.


// Note: DiffResult, StructuredDiff, Diffable protocol, and String/Array diff conformances
// are defined in Diffing.swift.

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

// Note: PropertyResult.prettyDescription, formatHistogram, formatClassificationTable,
// formatPropertyFailure, and formatCoverageStatus are defined in Formatters.swift.

/// **Helper function to separate documents**
func separatedBy(_ separator: Doc, _ docs: [Doc]) -> Doc {
  Doc.separatedBy(separator, docs)
}
