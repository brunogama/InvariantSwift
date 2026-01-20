/// FuzzableMacro - Macro for LibFuzzer integration
///
/// Part of ISP-0007: LibFuzzer Integration

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Fuzzable` macro for generating LibFuzzer entry points.
///
/// This macro processes a function and generates:
/// 1. An `LLVMFuzzerTestOneInput` C entry point
/// 2. A structured fuzz target for property testing
///
/// **Usage:**
/// ```swift
/// @Fuzzable(maxLength: 1024)
/// func parseProtobuf(_ data: Data) throws -> Message {
///     try Message(serializedData: data)
/// }
/// ```
public struct FuzzableMacro: PeerMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // For Phase 1, this is a marker macro
    // Full implementation would generate LLVMFuzzerTestOneInput
    // and FuzzTarget wrapper
    []
  }
}

/// `@StructuredInput` - marks a fuzzable function as taking structured input
///
/// Enables custom mutator generation that understands the type structure.
public struct StructuredInputMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Marker macro for structured fuzzing
    []
  }
}
