import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftAdvanced
// MARK: - @Regression Macro Declaration

/// Automatically save and replay failing property test examples.
///
/// Use `@Regression` alongside `@PropertyTest` to enable automatic persistence
/// of failing test cases. When a property test fails, the counterexample is saved
/// to the failing example database. On subsequent runs, saved failures are replayed
/// first before random generation to catch regressions immediately.
///
/// **Basic Usage:**
/// ```swift
/// @PropertyTest
/// @Regression
/// func testSorting(array: [Int]) {
///     let sorted = array.sorted()
///     #expect(sorted.isSorted)
/// }
/// ```
///
/// **How It Works:**
/// 1. When test fails, counterexample saved to `~/.invariant/examples/`
/// 2. On next run, saved examples replayed first (if `replayFirst: true`)
/// 3. If saved example now passes, it's marked as fixed and removed
/// 4. Then random generation continues as normal
///
/// **With Options:**
/// ```swift
/// @PropertyTest
/// @Regression(replayFirst: true, maxExamples: 10)
/// func testComplex(data: ComplexStruct) {
///     // Only replay up to 10 saved failures
/// }
/// ```
///
/// **Disabling Replay:**
/// ```swift
/// @PropertyTest
/// @Regression(replayFirst: false)
/// func testWithoutReplay(value: Int) {
///     // Save failures but don't replay on subsequent runs
/// }
/// ```
///
/// ## Environment Variables
///
/// - `INVARIANT_EXAMPLES_DISABLED=1` - Disable database entirely
/// - `INVARIANT_EXAMPLES_PATH=/path` - Custom database location
/// - `INVARIANT_CLEAR_EXAMPLES=1` - Clear database before run
///
/// ## Differences from @Reproduce
///
/// | Feature | @Reproduce | @Regression |
/// |---------|------------|-------------|
/// | Manual vs Auto | Manual (add after failure) | Automatic |
/// | Persistence | None (compile-time) | Disk (survives runs) |
/// | Replay | Single specific case | All saved failures |
/// | Use Case | Debugging specific failure | Regression prevention |
///
/// - Parameters:
///   - replayFirst: Whether to replay saved failures before random generation (default: true)
///   - maxExamples: Maximum number of saved examples to replay (default: all)
///
/// - Note: Mutually exclusive with @Reproduce. Use @Reproduce for debugging specific
///   failures, @Regression for ongoing regression prevention.
///
/// - See Also: ``PropertyTest``, ``Reproduce``, ``FailingExampleDatabase``
@attached(peer)
public macro Regression(
  replayFirst: Bool = true,
  maxExamples: Int? = nil,
  exposeCasesAsTests: Bool = false
) = #externalMacro(module: "InvariantSwiftMacros", type: "RegressionMacro")
