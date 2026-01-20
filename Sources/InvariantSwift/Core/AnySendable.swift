import Foundation

/// Type-erased wrapper for `Sendable` values.
///
/// `AnySendable` provides type erasure for any value conforming to `Sendable`, allowing
/// heterogeneous `Sendable` values to be stored in collections or passed through APIs
/// that need to work with multiple concrete `Sendable` types.
///
/// This type is particularly useful in property-based testing when you need to:
/// - Store generated values of different types in a uniform container
/// - Pass `Sendable` values through generic boundaries
/// - Build dynamic test data structures where exact types are unknown at compile time
///
/// Key characteristics:
/// - Conforms to `Sendable` itself, maintaining concurrency safety
/// - Preserves the original value internally with type information
/// - Supports safe type casting back to the original type via `base`
/// - Immutable by design to ensure thread safety
///
/// ## Concurrency Safety
///
/// `AnySendable` is marked as `@unchecked Sendable` because:
/// - It only stores values that already conform to `Sendable`
/// - The internal storage is immutable
/// - No mutable state is exposed
/// - Type erasure itself doesn't violate `Sendable` constraints
///
/// - Note: The wrapped value must conform to `Sendable`. Attempting to wrap
///   a non-`Sendable` value will result in a compile-time error.
///
/// - Example:
///   ```swift
///   let intValue = AnySendable(42)
///   let stringValue = AnySendable("hello")
///   let values: [AnySendable] = [intValue, stringValue]
///
///   // Retrieve original value
///   if let original = intValue.base as? Int {
///       print(original)  // 42
///   }
///   ```
///
/// - See Also: ``Gen``, ``Property``
public struct AnySendable: @unchecked Sendable {
  /// The type-erased value stored internally.
  private let storage: any Sendable

  /// Creates a type-erased wrapper for a `Sendable` value.
  ///
  /// Wraps the provided value in a type-erased container while maintaining
  /// `Sendable` conformance. The original type information is preserved and
  /// can be recovered through the ``base`` property.
  ///
  /// - Parameters:
  ///   - value: The `Sendable` value to wrap. Must conform to `Sendable` protocol.
  ///
  /// - Example:
  ///   ```swift
  ///   let wrapped = AnySendable(42)
  ///   let another = AnySendable([1, 2, 3])
  ///   let custom = AnySendable(MyCustomSendableType())
  ///   ```
  public init<T: Sendable>(_ value: T) {
    self.storage = value
  }

  /// The underlying type-erased `Sendable` value.
  ///
  /// Provides access to the wrapped value as an existential `any Sendable`.
  /// To retrieve the original concrete type, use type casting:
  ///
  /// - Example:
  ///   ```swift
  ///   let wrapped = AnySendable(42)
  ///
  ///   if let value = wrapped.base as? Int {
  ///       print(value)  // 42
  ///   }
  ///
  ///   // Pattern matching also works
  ///   switch wrapped.base {
  ///   case let int as Int:
  ///       print("Got an Int: \(int)")
  ///   case let string as String:
  ///       print("Got a String: \(string)")
  ///   default:
  ///       print("Unknown type")
  ///   }
  ///   ```
  public var base: any Sendable {
    storage
  }
}

// MARK: - Equatable Conformance

extension AnySendable: Equatable {
  /// Compares two `AnySendable` instances for equality.
  ///
  /// Two `AnySendable` values are equal if:
  /// - Their underlying values are of the same type
  /// - The underlying type conforms to `Equatable`
  /// - The underlying values are equal according to their `Equatable` implementation
  ///
  /// - Note: If the underlying types don't match or don't conform to `Equatable`,
  ///   this method returns `false`.
  ///
  /// - Example:
  ///   ```swift
  ///   let a = AnySendable(42)
  ///   let b = AnySendable(42)
  ///   let c = AnySendable(99)
  ///   let d = AnySendable("42")
  ///
  ///   assert(a == b)   // true - same type, same value
  ///   assert(a != c)   // true - same type, different value
  ///   assert(a != d)   // true - different types
  ///   ```
  public static func == (lhs: AnySendable, rhs: AnySendable) -> Bool {
    // Attempt to compare using Equatable if both values are the same type
    func areEqual<T: Equatable>(_ lhs: T, _ rhs: Any) -> Bool {
      guard let rhsTyped = rhs as? T else { return false }
      return lhs == rhsTyped
    }

    // Try common Sendable + Equatable types
    if let lhsInt = lhs.base as? Int { return areEqual(lhsInt, rhs.base) }
    if let lhsString = lhs.base as? String { return areEqual(lhsString, rhs.base) }
    if let lhsDouble = lhs.base as? Double { return areEqual(lhsDouble, rhs.base) }
    if let lhsBool = lhs.base as? Bool { return areEqual(lhsBool, rhs.base) }
    if let lhsArray = lhs.base as? [Int] { return areEqual(lhsArray, rhs.base) }
    if let lhsArray = lhs.base as? [String] { return areEqual(lhsArray, rhs.base) }

    // For other types, cannot determine equality without runtime type information
    return false
  }
}

// MARK: - Hashable Conformance

extension AnySendable: Hashable {
  /// Hashes the essential components of the `AnySendable` value.
  ///
  /// The hash value is computed based on the underlying value if it conforms to `Hashable`.
  /// For types that don't conform to `Hashable`, a default hash is used.
  ///
  /// - Note: Only common `Sendable + Hashable` types are hashed. For custom types,
  ///   consider extending this implementation or using a different approach.
  ///
  /// - Example:
  ///   ```swift
  ///   let set: Set<AnySendable> = [
  ///       AnySendable(42),
  ///       AnySendable("hello"),
  ///       AnySendable(42)  // Duplicate, will be deduplicated
  ///   ]
  ///   print(set.count)  // 2
  ///   ```
  public func hash(into hasher: inout Hasher) {
    // Hash based on common Sendable + Hashable types
    if let value = base as? Int {
      hasher.combine(value)
    } else if let value = base as? String {
      hasher.combine(value)
    } else if let value = base as? Double {
      hasher.combine(value)
    } else if let value = base as? Bool {
      hasher.combine(value)
    } else if let value = base as? [Int] {
      hasher.combine(value)
    } else if let value = base as? [String] {
      hasher.combine(value)
    } else {
      // For unknown types, use a constant hash to satisfy protocol requirements
      // This means different types will hash to the same value, but equality will still work correctly
      hasher.combine(0)
    }
  }
}

// MARK: - CustomStringConvertible

extension AnySendable: CustomStringConvertible {
  /// A textual representation of the wrapped value.
  ///
  /// Delegates to the underlying value's `description` if available,
  /// otherwise provides a generic representation.
  ///
  /// - Example:
  ///   ```swift
  ///   let wrapped = AnySendable(42)
  ///   print(wrapped)  // "42"
  ///
  ///   let anotherWrapped = AnySendable([1, 2, 3])
  ///   print(anotherWrapped)  // "[1, 2, 3]"
  ///   ```
  public var description: String {
    if let describable = base as? CustomStringConvertible {
      return describable.description
    }
    return "\(base)"
  }
}

// MARK: - CustomDebugStringConvertible

extension AnySendable: CustomDebugStringConvertible {
  /// A textual representation suitable for debugging.
  ///
  /// Includes type information to help identify the wrapped value during debugging.
  ///
  /// - Example:
  ///   ```swift
  ///   let wrapped = AnySendable(42)
  ///   debugPrint(wrapped)  // "AnySendable(Int: 42)"
  ///   ```
  public var debugDescription: String {
    let typeName = String(describing: type(of: base))
    if let debugDescribable = base as? CustomDebugStringConvertible {
      return "AnySendable(\(typeName): \(debugDescribable.debugDescription))"
    }
    return "AnySendable(\(typeName): \(base))"
  }
}
