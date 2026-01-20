import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftExperimental

/// Verifies a function is deterministic: f(x) == f(x) across multiple calls.
///
/// `@Deterministic` generates a property-based test that verifies calling
/// a function multiple times with the same input always produces the same output.
/// This is essential for functions used in hashing, serialization, and any
/// operation that must be reproducible.
///
/// **Mathematical Definition:**
/// A function `f` is deterministic if and only if calling `f(x)` multiple times
/// with identical `x` always produces identical results.
///
/// **Common Use Cases:**
/// - **Hashing**: Hash functions must always produce same hash for same input
/// - **Serialization**: JSON encoding should be deterministic
/// - **Reproducibility**: Scientific computations, build systems, test fixtures
/// - **Caching Keys**: Key generation must be consistent
/// - **Database Queries**: Same query parameters should return same results
///
/// **Requirements:**
/// - Function must return a value (not Void)
/// - Return type must conform to `Equatable`
/// - Function should not depend on external mutable state
///
/// **Basic Usage:**
/// ```swift
/// @Deterministic
/// func computeHash(_ data: Data) -> Int {
///   // Hash computation must be deterministic
///   var hasher = Hasher()
///   hasher.combine(data)
///   return hasher.finalize()
/// }
/// ```
///
/// **With Custom Configuration:**
/// ```swift
/// @Deterministic(iterations: 200, callCount: 5)
/// func generateId(from user: User) -> UUID {
///   // ID generation should be deterministic for same user
///   UUID(uuidString: user.email.sha256())!
/// }
/// ```
///
/// **Async Functions:**
/// ```swift
/// @Deterministic
/// func fetchConfiguration(for key: String) async -> Config {
///   // Configuration fetch should be deterministic
///   await configService.fetch(key)
/// }
/// ```
///
/// **Non-Deterministic Anti-Patterns:**
/// ```swift
/// // ❌ BAD: Uses random number generator
/// func generateToken() -> String {
///   UUID().uuidString // Different every call!
/// }
///
/// // ❌ BAD: Uses current time
/// func timestamp() -> Date {
///   Date() // Different every call!
/// }
///
/// // ✅ GOOD: Same input → same output
/// func deriveToken(from seed: String) -> String {
///   seed.sha256()
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
/// @Deterministic
/// func computeHash(_ data: Data) -> Int {
///   var hasher = Hasher()
///   hasher.combine(data)
///   return hasher.finalize()
/// }
///
/// // Expands to:
/// private enum computeHash_DeterministicTest {
///   @Test static func run() throws {
///     let generator = Gen<Data>.data
///     let property = Property(generator: generator) { data in
///       let call1 = computeHash(data)
///       let call2 = computeHash(data)
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
/// - See Also: ``Idempotent``, ``Property``, ``PropertyConfig``
@attached(peer, names: suffixed(_DeterministicTest))
public macro Deterministic(
  iterations: Int = 100,
  callCount: Int = 2
) = #externalMacro(module: "InvariantSwiftMacros", type: "DeterministicMacro")
