import Foundation

// MARK: - Property Combinator Operators

// Note: We use Swift's built-in && and || operators (LogicalConjunctionPrecedence
// and LogicalDisjunctionPrecedence) rather than defining custom operators.
// This ensures no ambiguity with boolean expressions.

// MARK: - Logical AND Operator

/// Combine two properties with logical AND (conjunction).
///
/// Creates a property that passes only when both properties pass on the same input.
/// Uses **short-circuit evaluation**: if the left property fails, the right property
/// is not evaluated.
///
/// Both properties must have the same generator type. The combined property uses the
/// same generator and checks both predicates sequentially.
///
/// - Parameters:
///   - lhs: First property to check
///   - rhs: Second property to check (evaluated only if lhs passes)
///
/// - Returns: A property that passes only when both lhs and rhs pass
///
/// - Example:
///   ```swift
///   let positive = Property(generator: Gen.int) { $0 > 0 }
///   let even = Property(generator: Gen.int) { $0.isMultiple(of: 2) }
///   let positiveEven = positive && even
///   // Passes only for values that are both positive AND even
///   ```
///
/// - Note: Short-circuit evaluation means if `lhs.predicate(value)` returns false,
///         `rhs.predicate(value)` is never called. This is both a performance
///         optimization and a safety feature (prevents errors in rhs when lhs fails).
///
/// - See Also: ``||(_:_:)``, ``Property``
// swiftlint:disable:next static_operator
public func && <T>(lhs: Property<T>, rhs: Property<T>) -> Property<T> {
  Property(
    generator: lhs.generator,
    assumption: { value in
      lhs.assumption(value) && rhs.assumption(value)
    },
    predicate: { value in
      // Short-circuit: only evaluate rhs if lhs passes
      guard lhs.predicate(value) else { return false }
      return rhs.predicate(value)
    }
  )
}

// MARK: - Logical OR Operator

/// Combine two properties with logical OR (disjunction).
///
/// Creates a property that passes when either property passes on the same input.
/// Uses **short-circuit evaluation**: if the left property passes, the right property
/// is not evaluated.
///
/// Both properties must have the same generator type. The combined property uses the
/// same generator and checks both predicates sequentially.
///
/// - Parameters:
///   - lhs: First property to check
///   - rhs: Second property to check (evaluated only if lhs fails)
///
/// - Returns: A property that passes when either lhs or rhs passes
///
/// - Example:
///   ```swift
///   let negative = Property(generator: Gen.int) { $0 < 0 }
///   let zero = Property(generator: Gen.int) { $0 == 0 }
///   let nonPositive = negative || zero
///   // Passes for values that are either negative OR zero
///   ```
///
/// - Note: Short-circuit evaluation means if `lhs.predicate(value)` returns true,
///         `rhs.predicate(value)` is never called.
///
/// - See Also: ``&&(_:_:)``, ``Property``
// swiftlint:disable:next static_operator
public func || <T>(lhs: Property<T>, rhs: Property<T>) -> Property<T> {
  Property(
    generator: lhs.generator,
    assumption: { value in
      lhs.assumption(value) && rhs.assumption(value)
    },
    predicate: { value in
      // Short-circuit: only evaluate rhs if lhs fails
      if lhs.predicate(value) { return true }
      return rhs.predicate(value)
    }
  )
}

// MARK: - Implication (implies) Method

extension Property {
  /// Create a conditional property with a precondition.
  ///
  /// This method enables filtering test cases based on a precondition without
  /// treating filtered cases as failures. When the precondition is false, the
  /// test case is **discarded** (not failed).
  ///
  /// This is equivalent to the `==>` operator but as a method for chaining:
  /// ```swift
  /// property.implies { $0 > 0 }
  /// // Same as:
  /// // $0 > 0 ==> property.predicate($0)
  /// ```
  ///
  /// - Parameter precondition: Condition that must hold for testing.
  ///                          If false, the test case is discarded.
  ///
  /// - Returns: A property that discards when precondition is false,
  ///            and checks the original predicate when precondition is true.
  ///
  /// - Example:
  ///   ```swift
  ///   let divisionProperty = Property(generator: Gen.zip(Gen.int, Gen.int)) { (n, d) in
  ///     n / d * d == n
  ///   }.implies { (_, d) in d != 0 }
  ///   // Only tests division when divisor is non-zero
  ///   ```
  ///
  /// - Example:
  ///   ```swift
  ///   let sortedProperty = Property(generator: Gen.array(Gen.int)) { array in
  ///     array.sorted().first == array.min()
  ///   }.implies { !$0.isEmpty }
  ///   // Only tests sorting when array is non-empty
  ///   ```
  ///
  /// - Note: Discarded test cases don't count as failures but do count toward
  ///         the `maxDiscarded` limit in `PropertyConfig`. If too many cases
  ///         are discarded, the property test gives up.
  ///
  /// - See Also: ``==>(_:_:)-swift.func``, ``PropertyEvaluation.discard(reason:)``
  public func implies(
    _ precondition: @escaping @Sendable (T) -> Bool
  ) -> Property<T> {
    // Combine precondition with existing assumption
    let combinedAssumption: @Sendable (T) -> Bool = { value in
      self.assumption(value) && precondition(value)
    }

    return Property(
      generator: self.generator,
      assumption: combinedAssumption,
      predicate: self.predicate
    )
  }
}
