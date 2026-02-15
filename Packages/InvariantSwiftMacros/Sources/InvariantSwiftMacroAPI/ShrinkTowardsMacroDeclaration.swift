import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftAdvanced
/// Configures shrink behavior for a property test parameter.
///
/// Use this attribute on function parameters to guide shrinking toward
/// semantically meaningful values during property-based testing. When a property
/// fails, the shrinking process will preferentially explore values closer to the
/// specified target, producing more meaningful minimal counterexamples.
///
/// **Basic Usage:**
///
/// ```swift
/// @PropertyTest
/// func testPositiveCount(@ShrinkTowards(1) count: Int) -> Bool {
///   count > 0  // Precondition
///   // ... property logic
/// }
/// ```
///
/// **Why Use Shrink Hints:**
///
/// Without hints, shrinking uses generic strategies that may produce unhelpful counterexamples:
/// - Integers shrink toward 0
/// - Strings shrink toward ""
/// - Arrays shrink toward []
///
/// With `@ShrinkTowards`, you can guide shrinking toward domain-appropriate values:
/// - Counts shrink toward 1 (smallest valid positive)
/// - Identifiers shrink toward "test" (valid identifier)
/// - Non-empty arrays shrink toward single-element arrays
///
/// **Parameters:**
///
/// - Parameter target: The value to shrink toward. Must be a literal value compatible
///   with the parameter type.
///
/// **Supported Types:**
///
/// - Integers: `@ShrinkTowards(0)`, `@ShrinkTowards(1)`, `@ShrinkTowards(100)`
/// - Strings: `@ShrinkTowards("")`, `@ShrinkTowards("test")`
/// - Floating-point: `@ShrinkTowards(0.0)`, `@ShrinkTowards(1.0)`
/// - Booleans: `@ShrinkTowards(true)`, `@ShrinkTowards(false)`
///
/// **Examples:**
///
/// ```swift
/// // Shrink non-empty names toward "test" instead of ""
/// @PropertyTest
/// func testNonEmptyName(@ShrinkTowards("test") name: String) -> Bool {
///   !name.isEmpty
///   // ... property
/// }
///
/// // Shrink percentages toward 50 instead of 0
/// @PropertyTest
/// func testPercentage(@ShrinkTowards(50) percent: Int) -> Bool {
///   percent >= 0 && percent <= 100
///   // ... property
/// }
///
/// // Multiple parameters with different hints
/// @PropertyTest
/// func testRange(
///   @ShrinkTowards(0) min: Int,
///   @ShrinkTowards(100) max: Int
/// ) -> Bool {
///   min < max
/// }
/// ```
///
/// **How It Works:**
///
/// When a property fails:
/// 1. Standard shrinking produces candidates: `100 → 0, 50, 99`
/// 2. With `@ShrinkTowards(10)`: candidates become `100 → 10, 55, 77, 88`
/// 3. Shrinking explores values closer to the target first
/// 4. Produces minimal counterexample relative to the target
///
/// **Integration with PropertyMacro:**
///
/// The `@PropertyTest` macro automatically detects `@ShrinkTowards` attributes and
/// configures the shrinking strategy accordingly. No additional setup required.
///
/// **Limitations:**
///
/// - Target must be a compile-time literal (not a variable or expression)
/// - Target type must match the parameter type
/// - Only affects shrinking, not generation (use `@Gen` for custom generation)
///
/// - SeeAlso: `ShrinkHint`, `ShrinkTarget`, `@PropertyTest`
@attached(accessor)
public macro ShrinkTowards<T>(_ target: T) =
  #externalMacro(
    module: "InvariantSwiftMacros",
    type: "ShrinkTowardsMacro"
  )
