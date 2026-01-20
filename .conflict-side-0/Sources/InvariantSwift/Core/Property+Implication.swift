import Foundation

// MARK: - Implication Operator (S012)

/// Precedence group for the `==>` implication operator.
///
/// This operator has:
/// - Higher precedence than assignment (can use in assignments without parens)
/// - Lower precedence than comparison (write `x > 0 ==> property` naturally)
/// - Right associativity (chain as `a ==> b ==> c` means `a ==> (b ==> c)`)
///
/// - See Also: ``==>(_:_:)-swift.func``, ``==>(_:_:)-swift.func``
precedencegroup ImplicationPrecedence {
  higherThan: AssignmentPrecedence
  lowerThan: ComparisonPrecedence
  associativity: right
}

/// QuickCheck-style implication operator for conditional properties.
///
/// This operator enables readable precondition syntax:
/// ```swift
/// n > 0 ==> (n * 2 > n)
/// ```
///
/// rather than manual guards:
/// ```swift
/// guard n > 0 else { return .discard(reason: nil) }
/// return n * 2 > n ? .pass : .fail(reason: nil)
/// ```
///
/// - See Also: ``ImplicationPrecedence``, ``PropertyEvaluation``, ``assume(_:reason:)``
infix operator ==> : ImplicationPrecedence

// MARK: - Overload 1: Bool Consequent

/// Implication operator with Boolean consequent.
///
/// This is the most common overload for simple conditional properties.
/// If the precondition is false, the test case is **discarded** (not failed).
/// If the precondition is true, the consequent is evaluated and determines pass/fail.
///
/// The consequent is **short-circuit evaluated**: it is only evaluated when the
/// precondition is true. This prevents unnecessary computation and potential errors
/// when preconditions are not met.
///
/// - Parameters:
///   - precondition: If false, test case is discarded
///   - consequent: Evaluated only when precondition is true; determines pass/fail
///
/// - Returns: `.discard(reason: nil)` if precondition is false,
///            `.pass` if consequent is true,
///            `.fail(reason: nil)` if consequent is false
///
/// - Example:
///   ```swift
///   @PropertyTest
///   func divisionProperty(n: Int, d: Int) -> PropertyEvaluation {
///     // Only test division when divisor is non-zero
///     d != 0 ==> ((n / d) * d == n)
///   }
///
///   @PropertyTest
///   func sortedProperty(xs: [Int]) -> PropertyEvaluation {
///     // Only test sorting when array is non-empty
///     !xs.isEmpty ==> (xs.sorted().first == xs.min())
///   }
///   ```
///
/// - Note: This operator matches QuickCheck's `==>` semantics exactly.
///         Compare with `assume()` function which provides the same behavior
///         but with explicit function call syntax.
///
/// - See Also: ``==>(_:_:)-swift.func``, ``assume(_:reason:)``, ``PropertyEvaluation``
// swiftlint:disable:next static_operator
public func ==> (
  precondition: Bool,
  consequent: @autoclosure () -> Bool
) -> PropertyEvaluation {
  guard precondition else { return .discard(reason: nil) }
  return consequent() ? .pass : .fail(reason: nil)
}

// MARK: - Overload 2: PropertyEvaluation Consequent

/// Implication operator with PropertyEvaluation consequent.
///
/// This overload enables explicit control over the evaluation result,
/// allowing custom reasons for pass/fail/discard outcomes.
///
/// The consequent is **short-circuit evaluated**: it is only evaluated when the
/// precondition is true.
///
/// - Parameters:
///   - precondition: If false, test case is discarded
///   - consequent: Evaluated only when precondition is true; provides explicit evaluation
///
/// - Returns: `.discard(reason: nil)` if precondition is false,
///            otherwise the result of evaluating consequent
///
/// - Example:
///   ```swift
///   @PropertyTest
///   func customReasonProperty(n: Int) -> PropertyEvaluation {
///     n > 0 ==> require(n * 2 > n, reason: "doubling should increase value")
///   }
///
///   @PropertyTest
///   func chainedProperty(n: Int) -> PropertyEvaluation {
///     n > 0 ==> (
///       n < 100 ==> require(n * n < 10000, reason: "square within bounds")
///     )
///   }
///   ```
///
/// - See Also: ``==>(_:_:)-swift.func``, ``require(_:reason:)``, ``PropertyEvaluation``
// swiftlint:disable:next static_operator
public func ==> (
  precondition: Bool,
  consequent: @autoclosure () -> PropertyEvaluation
) -> PropertyEvaluation {
  guard precondition else { return .discard(reason: nil) }
  return consequent()
}
