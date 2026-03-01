import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: - Type Analysis Utilities

/// Utilities for analyzing and extracting type information from SwiftSyntax.
public enum TypeAnalyzer {

  // MARK: - Type Extraction

  /// Extracts the simple name from a type, handling generics
  public static func typeName(from type: TypeSyntax) -> String {
    if let identifier = type.as(IdentifierTypeSyntax.self) {
      return identifier.name.text
    }
    if let optional = type.as(OptionalTypeSyntax.self) {
      return typeName(from: optional.wrappedType) + "?"
    }
    if let array = type.as(ArrayTypeSyntax.self) {
      return "[\(typeName(from: array.element))]"
    }
    if let member = type.as(MemberTypeSyntax.self) {
      return "\(typeName(from: member.baseType)).\(member.name.text)"
    }
    return type.trimmedDescription
  }

  /// Checks if type is Optional<T>
  public static func isOptional(_ type: TypeSyntax) -> Bool {
    type.is(OptionalTypeSyntax.self)
      || (type.as(IdentifierTypeSyntax.self)?.name.text == "Optional")
  }

  /// Unwraps Optional<T> to T, returns nil if not optional
  public static func unwrapOptional(_ type: TypeSyntax) -> TypeSyntax? {
    if let optional = type.as(OptionalTypeSyntax.self) {
      return optional.wrappedType
    }
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Optional",
      let args = identifier.genericArgumentClause,
      let first = args.arguments.first
    {
      // SwiftSyntax 602: arg.argument is Argument enum; extract TypeSyntax via .as
      return first.argument.as(TypeSyntax.self)
    }

    return nil
  }

  /// Checks if type is Array<T> or [T]
  public static func isArray(_ type: TypeSyntax) -> Bool {
    type.is(ArrayTypeSyntax.self) || (type.as(IdentifierTypeSyntax.self)?.name.text == "Array")
  }

  /// Extracts element type from Array<T> or [T]
  public static func arrayElementType(_ type: TypeSyntax) -> TypeSyntax? {
    if let array = type.as(ArrayTypeSyntax.self) {
      return array.element
    }
    if let identifier = type.as(IdentifierTypeSyntax.self),
      identifier.name.text == "Array",
      let args = identifier.genericArgumentClause,
      let first = args.arguments.first
    {
      // SwiftSyntax 602: arg.argument is Argument enum; extract TypeSyntax via .as
      return first.argument.as(TypeSyntax.self)
    }
    return nil
  }

  /// Checks if type is Set<T>
  public static func isSet(_ type: TypeSyntax) -> Bool {
    type.as(IdentifierTypeSyntax.self)?.name.text == "Set"
  }

  /// Checks if type is Dictionary<K, V>
  public static func isDictionary(_ type: TypeSyntax) -> Bool {
    let name = type.as(IdentifierTypeSyntax.self)?.name.text
    return name == "Dictionary" || type.is(DictionaryTypeSyntax.self)
  }

  /// Extracts generic arguments from a type
  public static func genericArguments(_ type: TypeSyntax) -> [TypeSyntax] {
    guard let identifier = type.as(IdentifierTypeSyntax.self),
      let args = identifier.genericArgumentClause
    else {
      return []
    }
    // SwiftSyntax 602: arg.argument is Argument enum; extract TypeSyntax via .as
    return args.arguments.compactMap { arg in
      arg.argument.as(TypeSyntax.self)
    }
  }
}

// MARK: - Primitive Type Detection

extension TypeAnalyzer {

  /// Set of known primitive types with built-in generators
  public static let primitiveTypes: Set<String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Float", "Double",
    "Bool",
    "String", "Character",
    "UUID", "Date", "Data", "URL",
  ]

  /// Checks if type has a built-in generator
  public static func isPrimitive(_ type: TypeSyntax) -> Bool {
    let name = baseTypeName(from: type)
    return primitiveTypes.contains(name)
  }

  /// Gets base type name without generics or optionality
  public static func baseTypeName(from type: TypeSyntax) -> String {
    if let optional = type.as(OptionalTypeSyntax.self) {
      return baseTypeName(from: optional.wrappedType)
    }
    if let identifier = type.as(IdentifierTypeSyntax.self) {
      return identifier.name.text
    }
    if type.is(ArrayTypeSyntax.self) {
      return "Array"
    }
    return type.trimmedDescription
  }
}
