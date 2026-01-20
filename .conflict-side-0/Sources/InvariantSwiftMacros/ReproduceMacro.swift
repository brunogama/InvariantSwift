/// ReproduceMacro - Macro for deterministic failure replay
///
/// Part of ISP-0004: Example Database and Reproducible Failures

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Reproduce` macro for deterministic replay of failing test cases.
///
/// This is a peer macro that works alongside `@PropertyTest` to fix the
/// generation parameters for exact reproduction of a failure.
///
/// **Usage:**
/// ```swift
/// @PropertyTest
/// @Reproduce(seed: 0xDEADBEEF, size: 42)
/// func testSorting(array: [Int]) {
///     // Will generate exact same array every time
/// }
/// ```
public struct ReproduceMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // This macro doesn't generate peers itself - it's a marker
    // that PropertyTestMacro reads to configure reproduction
    []
  }
}

// MARK: - Reproduce Configuration Extraction

/// Configuration extracted from @Reproduce attribute
public struct ReproduceConfig {
  public let seed: UInt64
  public let size: Int?
  public let shrinkPath: [Int]?
  public let serializedInput: String?

  public init(
    seed: UInt64,
    size: Int? = nil,
    shrinkPath: [Int]? = nil,
    serializedInput: String? = nil
  ) {
    self.seed = seed
    self.size = size
    self.shrinkPath = shrinkPath
    self.serializedInput = serializedInput
  }
}

/// Helper to extract @Reproduce configuration from attributes
public enum ReproduceExtractor {

  /// Extract configuration from a function's attributes
  public static func extractConfig(from funcDecl: FunctionDeclSyntax) -> ReproduceConfig? {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "Reproduce"
      else { continue }

      return parseReproduceAttribute(attrSyntax)
    }
    return nil
  }

  private static func parseReproduceAttribute(_ attr: AttributeSyntax) -> ReproduceConfig? {
    guard let args = attr.arguments?.as(LabeledExprListSyntax.self) else {
      return nil
    }

    var seed: UInt64?
    var size: Int?
    var path: [Int]?
    var input: String?

    for arg in args {
      let label = arg.label?.text

      switch label {
      case "seed":
        seed = extractUInt64(from: arg.expression)

      case "size":
        size = extractInt(from: arg.expression)

      case "path":
        if let pathStr = extractString(from: arg.expression) {
          path = pathStr.split(separator: ":").compactMap { Int($0) }
        }

      case "input":
        input = extractString(from: arg.expression)

      default:
        // First unlabeled argument is seed
        if label == nil, seed == nil {
          seed = extractUInt64(from: arg.expression)
        }
      }
    }

    guard let finalSeed = seed else { return nil }

    return ReproduceConfig(
      seed: finalSeed,
      size: size,
      shrinkPath: path,
      serializedInput: input
    )
  }

  private static func extractUInt64(from expr: ExprSyntax) -> UInt64? {
    if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
      let text = intLiteral.literal.text
      if text.hasPrefix("0x") || text.hasPrefix("0X") {
        return UInt64(String(text.dropFirst(2)), radix: 16)
      }
      return UInt64(text)
    }
    return nil
  }

  private static func extractInt(from expr: ExprSyntax) -> Int? {
    if let intLiteral = expr.as(IntegerLiteralExprSyntax.self) {
      return Int(intLiteral.literal.text)
    }
    return nil
  }

  private static func extractString(from expr: ExprSyntax) -> String? {
    if let stringLiteral = expr.as(StringLiteralExprSyntax.self),
      let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
    {
      return segment.content.text
    }
    return nil
  }
}
