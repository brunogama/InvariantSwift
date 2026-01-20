import SwiftSyntax

/// Helper extension to bridge SwiftSyntax 602+ GenericArgumentSyntax.Argument enum
extension GenericArgumentSyntax.Argument {
  /// Extracts the TypeSyntax from the argument, returning nil if it's an expression
  public var asType: TypeSyntax? {
    if case .type(let type) = self {
      return type
    }
    return nil
  }
}
