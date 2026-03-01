import SwiftSyntax

// MARK: - GenericArgument Compatibility

/// In SwiftSyntax 600.0.1, `GenericArgumentSyntax.argument` is `TypeSyntax` directly.
/// This extension provides a compatibility bridge for code that previously expected
/// a tagged-union approach.
extension GenericArgumentSyntax {
  /// Returns the argument as `TypeSyntax` (always succeeds in SwiftSyntax 600.0.1).
  public var argumentType: TypeSyntax {
    argument
  }
}
