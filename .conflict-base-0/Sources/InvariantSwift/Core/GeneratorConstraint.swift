/// GeneratorConstraint - Constraint DSL for #draw
///
/// Provides type-safe constraints for dependent generator construction.
/// Used with the `#draw` expression macro from ISP-0002.

import Foundation

// MARK: - Generator Constraint

/// Constraints for the `#draw` expression macro.
///
/// `GeneratorConstraint` provides a DSL for specifying conditions that generated
/// values must satisfy. The macro transforms these into appropriate `suchThat`
/// calls with optimized shrinking.
///
/// **Usage:**
/// ```swift
/// @Composite
/// func orderedPair() -> Gen<(Int, Int)> {
///     let a = #draw(Int.self)
///     let b = #draw(Int.self, .greaterThan(a))
///     return (a, b)
/// }
/// ```
public struct GeneratorConstraint<T: Sendable>: Sendable {

  /// The predicate that values must satisfy
  public let predicate: @Sendable (T) -> Bool

  /// Description for error messages
  public let description: String

  /// Creates a custom constraint
  public init(
    description: String,
    predicate: @escaping @Sendable (T) -> Bool
  ) {
    self.description = description
    self.predicate = predicate
  }
}

// MARK: - Numeric Constraints

extension GeneratorConstraint where T: Comparable {

  /// Value must be greater than the specified bound
  ///
  /// ```swift
  /// let b = #draw(Int.self, .greaterThan(a))
  /// ```
  public static func greaterThan(_ value: T) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "greaterThan(\(value))",
      predicate: { $0 > value }
    )
  }

  /// Value must be greater than or equal to the specified bound
  public static func greaterThanOrEqual(_ value: T) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "greaterThanOrEqual(\(value))",
      predicate: { $0 >= value }
    )
  }

  /// Value must be less than the specified bound
  ///
  /// ```swift
  /// let a = #draw(Int.self, .lessThan(b))
  /// ```
  public static func lessThan(_ value: T) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "lessThan(\(value))",
      predicate: { $0 < value }
    )
  }

  /// Value must be less than or equal to the specified bound
  public static func lessThanOrEqual(_ value: T) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "lessThanOrEqual(\(value))",
      predicate: { $0 <= value }
    )
  }

  /// Value must be within the specified range
  ///
  /// ```swift
  /// let age = #draw(Int.self, .between(0...120))
  /// ```
  public static func between(_ range: ClosedRange<T>) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "between(\(range))",
      predicate: { range.contains($0) }
    )
  }
}

// MARK: - Equality Constraints

extension GeneratorConstraint where T: Equatable {

  /// Value must not equal the specified value
  ///
  /// ```swift
  /// let other = #draw(Int.self, .notEqual(first))
  /// ```
  public static func notEqual(_ value: T) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "notEqual(\(value))",
      predicate: { $0 != value }
    )
  }

  /// Value must equal one of the specified values
  public static func oneOf(_ values: [T]) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "oneOf(\(values.count) values)",
      predicate: { values.contains($0) }
    )
  }

  /// Value must not be any of the specified values
  public static func noneOf(_ values: [T]) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "noneOf(\(values.count) values)",
      predicate: { !values.contains($0) }
    )
  }
}

// MARK: - Collection Constraints

extension GeneratorConstraint where T: Collection {

  /// Collection must not be empty
  ///
  /// ```swift
  /// let items = #draw([Product].self, .nonEmpty)
  /// ```
  public static var nonEmpty: GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "nonEmpty",
      predicate: { !$0.isEmpty }
    )
  }

  /// Collection must have count in the specified range
  ///
  /// ```swift
  /// let items = #draw([Int].self, .count(1..<10))
  /// ```
  public static func count(_ range: Range<Int>) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "count(\(range))",
      predicate: { range.contains($0.count) }
    )
  }

  /// Collection must have count in the specified closed range
  public static func count(_ range: ClosedRange<Int>) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "count(\(range))",
      predicate: { range.contains($0.count) }
    )
  }

  /// Collection must have exact count
  public static func count(_ exact: Int) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "count(\(exact))",
      predicate: { $0.count == exact }
    )
  }
}

extension GeneratorConstraint where T: Collection, T.Element: Equatable & Sendable {

  /// Collection must contain the specified element
  ///
  /// ```swift
  /// let numbers = #draw([Int].self, .containing(42))
  /// ```
  public static func containing(_ element: T.Element) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "containing(\(element))",
      predicate: { $0.contains(element) }
    )
  }

  /// Collection must not contain the specified element
  public static func notContaining(_ element: T.Element) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "notContaining(\(element))",
      predicate: { !$0.contains(element) }
    )
  }
}

extension GeneratorConstraint where T: Collection, T.Element: Hashable {

  /// Collection must have all unique elements
  ///
  /// ```swift
  /// let uniqueIds = #draw([UUID].self, .unique)
  /// ```
  public static var unique: GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "unique",
      predicate: { collection in
        var seen = Set<T.Element>()
        for element in collection {
          if seen.contains(element) { return false }
          seen.insert(element)
        }
        return true
      }
    )
  }
}

// MARK: - String Constraints

extension GeneratorConstraint where T == String {

  /// String must match the regular expression pattern
  ///
  /// ```swift
  /// let email = #draw(String.self, .matching("^[^@]+@[^@]+\\.[^@]+$"))
  /// ```
  /// - Note: Uses NSRegularExpression for Sendable compatibility
  public static func matching(_ pattern: String) -> GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "matching(\(pattern))",
      predicate: { str in
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(str.startIndex..., in: str)
        return regex.firstMatch(in: str, range: range) != nil
      }
    )
  }

  /// String must contain only alphabetic characters
  ///
  /// ```swift
  /// let name = #draw(String.self, .alphabetic)
  /// ```
  public static var alphabetic: GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "alphabetic",
      predicate: { $0.allSatisfy(\.isLetter) }
    )
  }

  /// String must contain only alphanumeric characters
  public static var alphanumeric: GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "alphanumeric",
      predicate: { $0.allSatisfy { $0.isLetter || $0.isNumber } }
    )
  }

  /// String must contain only numeric characters
  public static var numeric: GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "numeric",
      predicate: { $0.allSatisfy(\.isNumber) }
    )
  }

  /// String must have length in the specified range
  public static func length(_ range: Range<Int>) -> GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "length(\(range))",
      predicate: { range.contains($0.count) }
    )
  }

  /// String must have length in the specified closed range
  public static func length(_ range: ClosedRange<Int>) -> GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "length(\(range))",
      predicate: { range.contains($0.count) }
    )
  }

  /// String must start with the specified prefix
  public static func hasPrefix(_ prefix: String) -> GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "hasPrefix(\(prefix))",
      predicate: { $0.hasPrefix(prefix) }
    )
  }

  /// String must end with the specified suffix
  public static func hasSuffix(_ suffix: String) -> GeneratorConstraint<String> {
    GeneratorConstraint(
      description: "hasSuffix(\(suffix))",
      predicate: { $0.hasSuffix(suffix) }
    )
  }
}

// MARK: - Optional Constraints

extension GeneratorConstraint where T: Sendable {

  /// Value must be non-nil (for optional types)
  public static func notNilConstraint<U: Sendable>() -> GeneratorConstraint<U?> {
    GeneratorConstraint<U?>(
      description: "notNil",
      predicate: { $0 != nil }
    )
  }

  /// Value must be nil
  public static func isNilConstraint<U: Sendable>() -> GeneratorConstraint<U?> {
    GeneratorConstraint<U?>(
      description: "isNil",
      predicate: { $0 == nil }
    )
  }
}

// MARK: - Custom Constraints

extension GeneratorConstraint {

  /// Custom predicate constraint
  ///
  /// ```swift
  /// let even = #draw(Int.self, .satisfying { $0 % 2 == 0 })
  /// ```
  public static func satisfying(
    _ description: String = "custom",
    _ predicate: @escaping @Sendable (T) -> Bool
  ) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: description,
      predicate: predicate
    )
  }
}

// MARK: - Constraint Combinators

extension GeneratorConstraint {

  /// Combine constraints with AND logic
  ///
  /// ```swift
  /// let value = #draw(Int.self, .greaterThan(0).and(.lessThan(100)))
  /// ```
  public func and(_ other: GeneratorConstraint<T>) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "(\(description) && \(other.description))",
      predicate: { self.predicate($0) && other.predicate($0) }
    )
  }

  /// Combine constraints with OR logic
  ///
  /// ```swift
  /// let value = #draw(Int.self, .lessThan(0).or(.greaterThan(100)))
  /// ```
  public func or(_ other: GeneratorConstraint<T>) -> GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "(\(description) || \(other.description))",
      predicate: { self.predicate($0) || other.predicate($0) }
    )
  }

  /// Negate a constraint
  ///
  /// ```swift
  /// let odd = #draw(Int.self, .satisfying({ $0 % 2 == 0 }).not)
  /// ```
  public var not: GeneratorConstraint<T> {
    GeneratorConstraint(
      description: "not(\(description))",
      predicate: { !self.predicate($0) }
    )
  }
}

// MARK: - Gen Extension for Constraints

extension Gen {

  /// Apply a constraint to the generator
  ///
  /// ```swift
  /// let positiveGen = Gen<Int>.int.constrained(by: .greaterThan(0))
  /// ```
  ///
  /// - Note: For property testing, consider using `Property(generator:assumption:predicate:)`
  ///   which provides proper discard tracking and `.gaveUp` semantics.
  public func constrained(by constraint: GeneratorConstraint<T>) -> Gen<T> where T: Sendable {
    self.suchThat(constraint.predicate)
  }

  /// Apply multiple constraints to the generator
  ///
  /// - Note: For property testing, consider using `Property(generator:assumption:predicate:)`
  ///   which provides proper discard tracking and `.gaveUp` semantics.
  public func constrained(by constraints: [GeneratorConstraint<T>]) -> Gen<T> where T: Sendable {
    constraints.reduce(self) { gen, constraint in
      gen.suchThat(constraint.predicate)
    }
  }
}
