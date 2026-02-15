import SwiftSyntax

/// Compatibility extension for SwiftSyntax 600.0.1
/// In 600.0.1, GenericArgumentSyntax.argument is TypeSyntax directly
/// In 602.0.0+, it's GenericArgumentSyntax.Argument enum with .type() case
extension TypeSyntax {
  /// Returns self for compatibility with code using .asType
  public var asType: TypeSyntax? {
    return self
  }
}
