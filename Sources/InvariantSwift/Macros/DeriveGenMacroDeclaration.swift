import InvariantSwift
import InvariantSwiftAdvanced
import InvariantSwiftCore
import Foundation

/// Automatically derives a `Gen<Self>` instance for a type.
///
/// This macro analyzes the structure of types and generates appropriate
/// generators with:
/// - Proper shrinking strategies for each field
/// - Recursive generation for nested types
/// - Constraint-aware generation for enums and optionals
/// - Integration with existing manual generators
///
/// Example:
/// ```swift
/// @DeriveGen
/// struct Person {
///     let name: String
///     let age: Int
///     let email: String?
/// }
/// // Generates: extension Person { static var gen: Gen<Person> { ... } }
///
/// @DeriveGen(customFields: ["name": "Gen.asciiString.suchThat { !$0.isEmpty }"])
/// struct User {
///     let name: String
///     let id: UUID
/// }
/// // Uses custom generator for name, derives others automatically
/// ```
@attached(member, names: named(gen))
@attached(extension, conformances: Generatable)
public macro DeriveGen(
  customFields: [String: String] = [:],
  maxDepth: Int = 5,
  sizeScaling: Double = 1.0,
  enableShrinking: Bool = true
) = #externalMacro(module: "InvariantSwiftMacros", type: "DeriveGenMacro")
