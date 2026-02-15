/// DifferentialTestMacro - Macro for comparing two implementations
///
/// Part of ISP-0005: Differential Testing

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@DifferentialTest` macro for comparing reference and candidate implementations.
///
/// This is a peer macro that generates a test comparing two functions on generated inputs.
///
/// **Usage:**
/// ```swift
/// @DifferentialTest(
///     reference: OldParser.parse,
///     candidate: NewParser.parse
/// )
/// func testParserMigration(input: String) { }
/// ```
public struct DifferentialTestMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // This macro works as a marker - the test generation is handled by
    // reading attributes on the function and generating appropriate test code.
    // For Phase 1, we return an empty array as the core logic is in DifferentialTester.
    []
  }
}

// MARK: - Differential Test Configuration

/// Configuration extracted from @DifferentialTest attribute
public struct DifferentialTestConfig {
  public let referencePath: String
  public let candidatePath: String
  public let hasCustomComparer: Bool
  public let errorBehavior: String?

  public init(
    referencePath: String,
    candidatePath: String,
    hasCustomComparer: Bool = false,
    errorBehavior: String? = nil
  ) {
    self.referencePath = referencePath
    self.candidatePath = candidatePath
    self.hasCustomComparer = hasCustomComparer
    self.errorBehavior = errorBehavior
  }
}

/// Helper to extract @DifferentialTest configuration from attributes
public enum DifferentialTestExtractor {

  /// Extract configuration from a function's attributes
  public static func extractConfig(from funcDecl: FunctionDeclSyntax) -> DifferentialTestConfig? {
    for attr in funcDecl.attributes {
      guard let attrSyntax = attr.as(AttributeSyntax.self),
        let ident = attrSyntax.attributeName.as(IdentifierTypeSyntax.self),
        ident.name.text == "DifferentialTest"
      else { continue }

      return parseDifferentialTestAttribute(attrSyntax)
    }
    return nil
  }

  private static func parseDifferentialTestAttribute(
    _ attr: AttributeSyntax
  ) -> DifferentialTestConfig? {
    guard let args = attr.arguments?.as(LabeledExprListSyntax.self) else {
      return nil
    }

    var reference: String?
    var candidate: String?
    var hasComparer = false
    var errorBehavior: String?

    for arg in args {
      let label = arg.label?.text

      switch label {
      case "reference":
        reference = extractMemberAccess(from: arg.expression)

      case "candidate":
        candidate = extractMemberAccess(from: arg.expression)

      case "comparing":
        hasComparer = true

      case "errorBehavior":
        errorBehavior = extractMemberAccess(from: arg.expression)

      default:
        break
      }
    }

    guard let ref = reference, let cand = candidate else {
      return nil
    }

    return DifferentialTestConfig(
      referencePath: ref,
      candidatePath: cand,
      hasCustomComparer: hasComparer,
      errorBehavior: errorBehavior
    )
  }

  private static func extractMemberAccess(from expr: ExprSyntax) -> String? {
    // Handle member access like OldParser.parse
    if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
      if let base = memberAccess.base {
        return "\(base).\(memberAccess.declName.baseName.text)"
      }
      return memberAccess.declName.baseName.text
    }
    // Handle simple identifier
    if let ident = expr.as(DeclReferenceExprSyntax.self) {
      return ident.baseName.text
    }
    return expr.description.trimmingCharacters(in: .whitespaces)
  }
}
