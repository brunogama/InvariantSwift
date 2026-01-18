/// ContractMacro - Macro for contract-based testing
///
/// Part of ISP-0006: Contract Testing

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Contract` macro for marking protocols with behavioral contracts.
///
/// This macro processes a protocol and generates conformance to `ContractProtocol`,
/// enabling automatic test generation for any conforming type.
///
/// **Usage:**
/// ```swift
/// @Contract
/// protocol Stack {
///     @Precondition { !$0.isEmpty }
///     @Postcondition { $0.count == old($0.count) - 1 }
///     mutating func pop() -> Element?
/// }
/// ```
public struct ContractMacro: MemberMacro, ExtensionMacro {

  // MARK: - MemberMacro

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // For Phase 1, we add a simple marker
    // Full implementation would collect preconditions/postconditions from methods
    []
  }

  // MARK: - ExtensionMacro

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Add ContractProtocol conformance
    let ext = try ExtensionDeclSyntax("extension \(type): ContractProtocol {}")
    return [ext]
  }
}

/// `@TestContract` macro for generating property tests for a contract.
///
/// **Usage:**
/// ```swift
/// @TestContract(Stack.self)
/// struct ArrayStackTests {
///     typealias SUT = ArrayStack<Int>
/// }
/// ```
public struct TestContractMacro: MemberMacro {

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Phase 1: Marker only
    // Full implementation would generate test methods for each contract
    []
  }
}

/// `@PostconditionContract` - marks a postcondition on a contract method
/// (Using different name to avoid conflict with ISP-0003 @Postcondition)
public struct PostconditionContractMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Marker macro - processing done by ContractMacro
    []
  }
}

/// `@PreconditionContract` - marks a precondition on a contract method
public struct PreconditionContractMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Marker macro - processing done by ContractMacro
    []
  }
}

/// `@Law` - marks an algebraic law that implementations must satisfy
public struct LawMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Marker macro - processing done by TestContractMacro
    []
  }
}
