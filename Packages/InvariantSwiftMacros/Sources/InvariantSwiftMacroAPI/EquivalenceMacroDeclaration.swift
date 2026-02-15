import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftExperimental
import Foundation

/// Verifies two function implementations produce equivalent outputs.
///
/// `@Equivalence` automates differential testing by comparing a reference
/// implementation against a candidate implementation across generated inputs.
/// Essential for safe refactoring, optimization validation, and cross-platform consistency.
///
/// **Basic Usage:**
/// ```swift
/// @Equivalence(iterations: 500)
/// func testSortingOptimization(
///   reference: @escaping ([Int]) -> [Int],
///   candidate: @escaping ([Int]) -> [Int]
/// ) {
///   // Macro generates: test comparing reference(input) vs candidate(input)
/// }
/// ```
///
/// **With Floating-Point Tolerance:**
/// ```swift
/// @Equivalence(iterations: 1000, tolerance: 1e-10)
/// func testFloatingPointCalculation(
///   reference: @escaping (Double) -> Double,
///   candidate: @escaping (Double) -> Double
/// ) {
///   // Uses FloatingPointTolerance.absolute(1e-10) for comparison
/// }
/// ```
///
/// ## When to Use
///
/// - **Refactoring Validation**: Verify new implementation matches old behavior
/// - **Optimization Verification**: Ensure optimized code produces same results
/// - **Cross-Platform Consistency**: Confirm implementations match across platforms
/// - **Algorithm Comparison**: Compare different algorithmic approaches
///
/// ## Requirements
///
/// - Function must accept exactly 2 parameters (reference and candidate)
/// - Both parameters must be function types with identical signatures
/// - Input types must have generators (primitive types or conforming to Generatable)
/// - Output types must be Equatable (or use tolerance for BinaryFloatingPoint)
///
/// ## Tolerance Parameter
///
/// Use `tolerance` for approximate floating-point comparison:
/// - Only valid when Output type is Double, Float, Float16, Float80, or CGFloat
/// - Uses `FloatingPointTolerance.absolute(tolerance)` internally
/// - Calls `isApproximatelyEqual(to:tolerance:)` instance method
/// - Compile error if tolerance specified for non-floating-point types
///
/// ## Generated Test Structure
///
/// The macro generates a Swift Testing `@Test` function that:
/// 1. Infers input generators from function parameter types
/// 2. Generates `iterations` random inputs
/// 3. Calls both reference and candidate with each input
/// 4. Compares outputs (exact or with tolerance)
/// 5. Reports divergences via `Issue.record()`
///
/// - Parameters:
///   - iterations: Number of random inputs to test (default: 500)
///   - tolerance: Optional absolute tolerance for floating-point comparison (default: nil)
///
/// - Throws: Compile-time error if:
///   - Applied to non-function
///   - Function doesn't have exactly 2 parameters
///   - Parameter types don't match (reference/candidate must have same signature)
///   - tolerance specified for non-BinaryFloatingPoint output type
///
/// - See Also: ``FloatingPointTolerance``, ``DifferentialTester``
@attached(peer, names: suffixed(_EquivalenceTest))
public macro Equivalence(
  iterations: Int = 500,
  tolerance: Double? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "EquivalenceMacro")
