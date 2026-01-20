/// RegressionMacro - Automatic failure persistence and replay
///
/// Part of ISP-0004: Example Database and Reproducible Failures

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Regression` macro for automatic failure persistence and replay.
///
/// This is a peer macro that works alongside `@PropertyTest` to automatically
/// save failing test cases to the example database and replay them before
/// random generation.
///
/// **Usage:**
/// ```swift
/// @PropertyTest
/// @Regression
/// func testSorting(array: [Int]) {
///     // Failures auto-saved, replayed on next run
/// }
/// ```
public struct RegressionMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // This macro doesn't generate peers itself - it's a marker
    // that PropertyTestMacro reads to configure automatic failure
    // persistence and replay-first behavior
    []
  }
}
