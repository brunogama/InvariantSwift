import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of @ShrinkTowards attribute macro.
///
/// This is a marker macro that provides metadata to PropertyMacro for configuring
/// shrinking behavior. It does not generate code itself; instead, PropertyMacro
/// extracts the target value from the attribute and uses it to configure shrinking.
///
/// Pattern: Similar to @Reproduce and @Regression marker macros.
public struct ShrinkTowardsMacro: AccessorMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    // Marker macro: no code generation
    // PropertyMacro will extract the target value from the attribute arguments
    []
  }
}
