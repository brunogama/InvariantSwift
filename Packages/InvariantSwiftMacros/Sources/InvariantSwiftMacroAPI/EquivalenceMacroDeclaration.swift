import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftAdvanced
import Foundation

/// Verifies two function implementations produce equivalent outputs.
///
/// `@Equivalence` automates differential testing by comparing a reference
/// implementation against a candidate implementation across generated inputs.
/// Essential for safe refactoring, optimization validation, and cross-platform consistency.
///
/// The generated test is a *peer* of the annotated function, so the annotated function's
/// parameters are not in scope inside it. Name the implementations to compare as default
/// values on both parameters; the macro rebinds those defaults inside the generated test.
/// The annotated function is never called - it only carries the signature.
///
/// **Basic Usage:**
/// ```swift
/// @Equivalence(iterations: 500)
/// func testSortingOptimization(
///   reference: @escaping ([Int]) -> [Int] = bubbleSort,
///   candidate: @escaping ([Int]) -> [Int] = quickSort
/// ) {}
/// ```
///
/// which expands to a peer enum holding the test:
/// ```swift
/// private enum testSortingOptimization_EquivalenceTest {
///   @Test("testSortingOptimization") static func run() throws {
///     let reference: ([Int]) -> [Int] = bubbleSort
///     let candidate: ([Int]) -> [Int] = quickSort
///     for _ in 0 ..< 500 {
///       var rng = SystemRandomNumberGenerator.init()
///       let input = Gen.array(Gen<Int>.int).generate(&rng, Size.default)
///       let referenceResult = reference(input)
///       let candidateResult = candidate(input)
///       if referenceResult != candidateResult {
///         Issue.record(Comment(rawValue: "Equivalence test failed: ..."))
///       }
///     }
///   }
/// }
/// ```
///
/// **With Floating-Point Tolerance:**
/// ```swift
/// @Equivalence(iterations: 1000, tolerance: 1e-10)
/// func testFloatingPointCalculation(
///   reference: @escaping (Double) -> Double = naiveSum,
///   candidate: @escaping (Double) -> Double = kahanSum
/// ) {
///   // Uses FloatingPointTolerance.absolute(1e-10) for comparison
/// }
/// ```
///
/// **Effectful and Multi-Input Implementations:**
/// ```swift
/// @Equivalence(iterations: 100)
/// func testAsyncFetch(
///   reference: @escaping (Int) async -> Int = oldFetch,
///   candidate: @escaping (Int) async -> Int = newFetch
/// ) {}
/// // Generates `static func run() async throws` and awaits both calls.
/// ```
/// - A `throws` closure type produces `try reference(input)` / `try candidate(input)`
/// - An `async` closure type produces an `async throws` test that awaits both calls
/// - A multi-input closure type spreads the generated tuple: `reference(input.0, input.1)`
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
/// - Both parameters must be function types; an `@escaping` attribute is accepted and
///   stripped from the binding the generated test declares
/// - Both parameters must have a default value naming the implementation to compare, and
///   that implementation must be visible from the generated peer's scope
/// - The candidate's signature must match the reference's: input generators, effects, and
///   the compared output type are all derived from the reference parameter's type
/// - Input types must have generators (primitive types or conforming to Generatable)
/// - Output types must be Equatable (or use tolerance for BinaryFloatingPoint)
///
/// ## Tolerance Parameter
///
/// Use `tolerance` for approximate floating-point comparison:
/// - Only valid when the reference's return type is Double, Float, Float16, Float80, or
///   CGFloat
/// - Uses `FloatingPointTolerance.absolute(tolerance)` internally
/// - Calls `isApproximatelyEqual(to:tolerance:)` instance method
/// - Compile error if tolerance specified for non-floating-point types
///
/// ## Generated Test Structure
///
/// The macro generates a private peer `enum <functionName>_EquivalenceTest` containing one
/// static Swift Testing `@Test` function, `run()`, that:
/// 1. Rebinds each parameter's default value to that parameter's own name
/// 2. Infers input generators from the reference closure's parameter types
/// 3. Generates `iterations` random inputs
/// 4. Calls both reference and candidate with each input, adding `try` / `await` as needed
/// 5. Compares outputs (exact or with tolerance)
/// 6. Reports divergences via `Issue.record()`
///
/// - Parameters:
///   - iterations: Number of random inputs to test (default: 500)
///   - tolerance: Optional absolute tolerance for floating-point comparison (default: nil)
///
/// - Throws: Compile-time error if:
///   - Applied to non-function
///   - Function doesn't have exactly 2 parameters
///   - Either parameter is not a function type
///   - Either parameter has no default value naming the implementation to compare
///   - tolerance specified for non-BinaryFloatingPoint output type
///
/// - See Also: ``FloatingPointTolerance``, ``DifferentialTester``
@attached(peer, names: suffixed(_EquivalenceTest))
public macro Equivalence(
  iterations: Int = 500,
  tolerance: Double? = nil
) = #externalMacro(module: "InvariantSwiftMacros", type: "EquivalenceMacro")
