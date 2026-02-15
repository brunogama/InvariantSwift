// MARK: - GhostwriterCLI Type Checking
// Type generatability checking utilities.

import Foundation

extension GhostwriterCLI {
  /// Known types that have built-in Arbitrary generators.
  static let knownGeneratableTypes: Set<String> = [
    // Primitives
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Double", "Float", "Bool", "String", "Character",
    // Foundation types
    "Date", "UUID", "URL", "Data",
    // Core types
    "Seed", "Size",
  ]

  /// Check if a type name is a known generatable type.
  static func isKnownGeneratableType(_ name: String) -> Bool {
    knownGeneratableTypes.contains(name)
  }

  /// Check if a type can have Arbitrary auto-generated.
  static func canAutoGenerateArbitrary(for type: ExtractedTypeInfo) -> Bool {
    guard !type.properties.isEmpty else { return false }
    return type.properties.allSatisfy { prop in
      isPropertyTypeGeneratable(prop.typeName)
    }
  }

  /// Check if a property type can be generated.
  static func isPropertyTypeGeneratable(_ typeName: String) -> Bool {
    let cleanedType = cleanTypeName(typeName)
    return checkTypeGeneratability(cleanedType)
  }

  private static func cleanTypeName(_ typeName: String) -> String {
    var cleaned =
      typeName
      .replacingOccurrences(of: "?", with: "")
      .replacingOccurrences(of: "!", with: "")
      .trimmingCharacters(in: .whitespaces)

    if cleaned.hasPrefix("Optional<") && cleaned.hasSuffix(">") {
      cleaned = String(cleaned.dropFirst(9).dropLast())
    }

    return cleaned
  }

  private static func checkTypeGeneratability(_ cleanedType: String) -> Bool {
    // Handle Array<T>
    if cleanedType.hasPrefix("Array<") && cleanedType.hasSuffix(">") {
      let inner = String(cleanedType.dropFirst(6).dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    // Handle [T] syntax
    if cleanedType.hasPrefix("[") && cleanedType.hasSuffix("]") && !cleanedType.contains(":") {
      let inner = String(cleanedType.dropFirst().dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    // Handle Set<T>
    if cleanedType.hasPrefix("Set<") && cleanedType.hasSuffix(">") {
      let inner = String(cleanedType.dropFirst(4).dropLast())
      return isPropertyTypeGeneratable(inner)
    }

    // Handle Dictionary<K,V> / [K:V]
    if cleanedType.hasPrefix("Dictionary<")
      || (cleanedType.hasPrefix("[") && cleanedType.contains(":"))
    {
      return true
    }

    return knownGeneratableTypes.contains(cleanedType)
  }
}
