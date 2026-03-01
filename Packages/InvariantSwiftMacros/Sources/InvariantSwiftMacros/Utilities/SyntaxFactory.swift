import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Syntax Factory

/// Factory for creating common SwiftSyntax nodes.
/// Provides type-safe builders for frequently used patterns.
public enum SyntaxFactory {

  // MARK: - Identifiers & References

  /// Creates an identifier token
  public static func identifier(_ name: String) -> TokenSyntax {
    .identifier(name)
  }

  /// Creates a declaration reference expression: `name`
  public static func declRef(_ name: String) -> DeclReferenceExprSyntax {
    DeclReferenceExprSyntax(baseName: .identifier(name))
  }

  /// Creates a member access expression: `base.member`
  public static func memberAccess(
    base: ExprSyntax,
    member: String
  ) -> MemberAccessExprSyntax {
    MemberAccessExprSyntax(
      base: base,
      declName: DeclReferenceExprSyntax(baseName: .identifier(member))
    )
  }

  /// Creates a member access on a type: `Type.member`
  public static func memberAccess(
    type: String,
    member: String
  ) -> MemberAccessExprSyntax {
    memberAccess(base: ExprSyntax(declRef(type)), member: member)
  }

  // MARK: - Type Syntax

  /// Creates a simple identifier type: `Int`, `String`, etc.
  public static func simpleType(_ name: String) -> IdentifierTypeSyntax {
    IdentifierTypeSyntax(name: .identifier(name))
  }

  /// Creates a generic type: `Gen<Int>`, `Array<String>`, etc.
  public static func genericType(
    _ name: String,
    arguments: [TypeSyntax]
  ) -> some TypeSyntaxProtocol {
    IdentifierTypeSyntax(
      name: .identifier(name),
      genericArgumentClause: GenericArgumentClauseSyntax {
        for arg in arguments {
          GenericArgumentSyntax(argument: .init(arg))
        }
      }
    )
  }

  /// Creates an optional type: `T?`
  public static func optionalType(_ wrapped: TypeSyntax) -> OptionalTypeSyntax {
    OptionalTypeSyntax(wrappedType: wrapped)
  }

  /// Creates an array type: `[T]`
  public static func arrayType(_ element: TypeSyntax) -> ArrayTypeSyntax {
    ArrayTypeSyntax(element: element)
  }

  // MARK: - Literals

  /// Creates an integer literal
  public static func intLiteral(_ value: Int) -> IntegerLiteralExprSyntax {
    IntegerLiteralExprSyntax(literal: .integerLiteral("\(value)"))
  }

  /// Creates a string literal
  public static func stringLiteral(_ value: String) -> StringLiteralExprSyntax {
    StringLiteralExprSyntax(content: value)
  }

  /// Creates a boolean literal
  public static func boolLiteral(_ value: Bool) -> BooleanLiteralExprSyntax {
    BooleanLiteralExprSyntax(
      literal: value ? TokenSyntax.keyword(.true) : TokenSyntax.keyword(.false)
    )
  }

  /// Creates a nil literal
  public static func nilLiteral() -> NilLiteralExprSyntax {
    NilLiteralExprSyntax()
  }
}
