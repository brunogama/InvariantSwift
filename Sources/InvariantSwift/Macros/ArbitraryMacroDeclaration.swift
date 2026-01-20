import Foundation
import InvariantCore
/// Automatically derives a generator and shrinker for custom types.
///
/// `@Arbitrary` enables automatic generation of test values for structs and enums.
/// It analyzes the type's structure and generates appropriate `Gen<T>` and
/// optionally `Shrink<T>` implementations.
///
/// **Struct Usage:**
/// ```swift
/// @Arbitrary
/// struct User {
///     let name: String
///     let age: Int
/// }
/// ```
///
/// **Enum Usage:**
/// ```swift
/// @Arbitrary
/// enum PaymentMethod {
///     case cash
///     case creditCard(number: String, cvv: String)
/// }
/// ```
///
/// **With Shrinking Strategies:**
/// ```swift
/// @Arbitrary(shrink: .automatic)  // Default: derive from field types
/// @Arbitrary(shrink: .none)  // No shrinking
/// ```
///
/// - Parameters:
///   - shrink: Shrinking strategy (default: .automatic)
///   - constraints: Field constraints as [fieldName: constraintExpression]
///
/// - See Also: ``Property``, ``Gen``
@attached(member, names: named(arbitrary), named(shrink))
@attached(extension, conformances: Generatable)
public macro Arbitrary(
  shrink: ArbitraryShrinkStrategy = .automatic,
  constraints: [String: String] = [:]
) = #externalMacro(module: "InvariantSwiftMacros", type: "ArbitraryMacro")

/// Shrinking strategy for @Arbitrary macro.
public enum ArbitraryShrinkStrategy: Sendable {
  case automatic
  case none
  case toEmpty
  case dropFields
}

// Generatable protocol is now in Core/Generatable.swift
