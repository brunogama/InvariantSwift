import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@Timeout` macro.
///
/// This macro is a marker macro (PeerMacro) that doesn't generate any peer declarations.
/// Instead, it's detected by PropertyMacro, which reads the timeout configuration
/// and wraps the property test body with a `withPropertyTimeout` call.
///
/// ## Macro Pattern
///
/// This follows the same marker pattern as @Regression and @Reproduce:
/// 1. @Timeout is attached to a function as a marker
/// 2. PropertyMacro reads the @Timeout attribute using TimeoutExtractor
/// 3. PropertyMacro wraps the generated test body with withPropertyTimeout
///
/// ## Example Expansion
///
/// Input:
/// ```swift
/// @Timeout(seconds: 5.0)
/// @PropertyTest
/// func slowProperty(n: Int) -> Bool { ... }
/// ```
///
/// PropertyMacro generates (conceptually):
/// ```swift
/// let result = try await withPropertyTimeout(seconds: 5.0) {
///   try await runPropertyAsync(property, config: config)
/// }
/// ```
public struct TimeoutMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Marker macro - no peer declarations
    // PropertyMacro will detect this attribute and wrap the test body
    []
  }
}
