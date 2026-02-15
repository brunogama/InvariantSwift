import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftAdvanced

/// Verifies a function is pure: deterministic and referentially transparent.
///
/// `@Pure` generates a property-based test that verifies calling a function
/// multiple times with the same input always produces the same output. This is
/// a necessary (but not sufficient) condition for purity.
///
/// **IMPORTANT LIMITATION:**
/// Swift lacks compile-time effect tracking (unlike Haskell's type system).
/// @Pure can ONLY verify determinism (f(x) == f(x)). It CANNOT detect:
/// - State mutation (modifying captured variables, global state, etc.)
/// - Side effects (I/O, logging, network calls, database writes)
/// - Observable effects (throwing, randomness, time-dependent behavior)
///
/// **What @Pure Tests:**
/// - Determinism: Same input → same output
///
/// **What @Pure CANNOT Test:**
/// - State mutations: `var counter = 0; func f() { counter += 1; return counter }`
/// - Side effects: `func f() { Logger.log("side effect"); return 42 }`
/// - Hidden I/O: `func f() { saveToDatabase(); return true }`
///
/// **Recommendation:**
/// Use @Pure for functions you've manually verified have no side effects.
/// Consider this macro a documentation tool + determinism check, not a
/// proof of purity. Combine with code review to verify true purity.
///
/// **Mathematical Definition:**
/// A function `f` is pure if:
/// 1. Deterministic: f(x) == f(x) for all x (TESTED by this macro)
/// 2. Referentially transparent: No side effects (NOT tested, manual verification required)
///
/// **Use Cases for @Pure:**
/// - **Safe to Memoize**: Pure functions can be cached without correctness issues
/// - **Safe to Parallelize**: Pure functions can run concurrently without races
/// - **Safe to Reorder**: Compiler can optimize call order without affecting behavior
/// - **Testability**: Pure functions are easier to test (no setup/teardown needed)
///
/// **Requirements:**
/// - Function must return a value (not Void)
/// - Return type must conform to `Equatable`
/// - Function should be manually verified to have no side effects
///
/// **Basic Usage:**
/// ```swift
/// @Pure
/// func add(_ a: Int, _ b: Int) -> Int {
///   a + b  // No side effects, deterministic
/// }
/// ```
///
/// **With Custom Configuration:**
/// ```swift
/// @Pure(iterations: 200, callCount: 3)
/// func hash(_ data: Data) -> Int {
///   // Hash computation: deterministic, no side effects
///   var hasher = Hasher()
///   hasher.combine(data)
///   return hasher.finalize()
/// }
/// ```
///
/// **Async Functions:**
/// ```swift
/// @Pure
/// func computeExpensive(_ n: Int) async -> BigInt {
///   // Pure computation offloaded to async context
///   await Task { factorial(n) }.value
/// }
/// ```
///
/// **Examples of Pure Functions:**
/// ```swift
/// @Pure func double(_ x: Int) -> Int { x * 2 }
/// @Pure func reverse(_ s: String) -> String { String(s.reversed()) }
/// @Pure func max(_ a: Int, _ b: Int) -> Int { a > b ? a : b }
/// ```
///
/// **Non-Pure Anti-Patterns:**
/// ```swift
/// // ❌ BAD: Modifies global state (not caught by @Pure!)
/// var counter = 0
/// func incrementCounter() -> Int {
///   counter += 1  // Side effect!
///   return counter
/// }
///
/// // ❌ BAD: Uses random number generator (caught by @Pure)
/// func randomInt() -> Int {
///   Int.random(in: 0...100)  // Non-deterministic, test will fail
/// }
///
/// // ❌ BAD: I/O side effect (not caught by @Pure!)
/// func logAndReturn(_ x: Int) -> Int {
///   Logger.log("Logging: \(x)")  // Side effect!
///   return x
/// }
/// ```
///
/// **Generated Test:**
/// The macro generates a property test that:
/// 1. Generates random inputs using inferred generators
/// 2. Calls function `callCount` times with identical input
/// 3. Verifies all calls produce identical results
/// 4. Shrinks counterexamples to minimal failing case
///
/// **Example Expansion:**
/// ```swift
/// @Pure
/// func add(_ a: Int, _ b: Int) -> Int {
///   a + b
/// }
///
/// // Expands to:
/// private enum add_PureTest {
///   @Test static func run() throws {
///     let generator = Gen<Int>.int.flatMap { a in
///       Gen<Int>.int.map { b in (a, b) }
///     }
///     let property = Property(generator: generator) { (a, b) in
///       let call1 = add(a, b)
///       let call2 = add(a, b)
///       return call1 == call2
///     }
///     let config = PropertyConfig(iterations: 100, maxShrinks: 1000)
///     let result = runPropertySynchronously(property, config: config)
///     switch result {
///     case .success: break
///     case .failure: Issue.record(...)
///     case .gaveUp: Issue.record(...)
///     }
///   }
/// }
/// ```
///
/// - Parameters:
///   - iterations: Number of random test cases to generate (default: 100)
///   - callCount: How many times to call function with same input (default: 2)
///
/// - See Also: ``Idempotent``, ``Deterministic``, ``Property``, ``PropertyConfig``
@attached(peer, names: suffixed(_PureTest))
public macro Pure(
  iterations: Int = 100,
  callCount: Int = 2
) = #externalMacro(module: "InvariantSwiftMacros", type: "PureMacro")
