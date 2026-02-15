import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftAdvanced

/// Verifies a function is idempotent: f(f(x)) == f(x).
///
/// `@Idempotent` generates a property-based test that verifies applying
/// a function multiple times produces the same result as applying it once.
/// This is a fundamental property for operations like data normalization,
/// caching, and retry logic.
///
/// **Mathematical Definition:**
/// A function `f` is idempotent if and only if `f(f(x)) == f(x)` for all `x`.
///
/// **Common Use Cases:**
/// - **Data Normalization**: String trimming, case conversion, URL encoding
/// - **Caching**: Cache writes should be idempotent (write twice = write once)
/// - **Retry Logic**: Retrying a failed operation should not cause side effects
/// - **Database Operations**: UPDATE statements, upsert operations
///
/// **Requirements:**
/// - Function must return a value (not Void)
/// - Return type must conform to `Equatable`
/// - Function should be pure (no observable side effects)
///
/// **Basic Usage:**
/// ```swift
/// @Idempotent
/// func normalize(_ text: String) -> String {
///   text.trimmingCharacters(in: .whitespaces).lowercased()
/// }
/// ```
///
/// **With Custom Configuration:**
/// ```swift
/// @Idempotent(iterations: 200, applicationCount: 3)
/// func compress(_ data: Data) -> Data {
///   // Compression should be idempotent
///   // compress(compress(x)) == compress(x)
/// }
/// ```
///
/// **Async Functions:**
/// ```swift
/// @Idempotent
/// func fetchAndCache(key: String) async -> CachedValue {
///   // Fetching twice should return same cached value
/// }
/// ```
///
/// **Generated Test:**
/// The macro generates a property test that:
/// 1. Generates random inputs using inferred generators
/// 2. Applies function `applicationCount` times
/// 3. Verifies applying once more produces same result
/// 4. Shrinks counterexamples to minimal failing case
///
/// **Example Expansion:**
/// ```swift
/// @Idempotent
/// func normalize(_ text: String) -> String {
///   text.trimmingCharacters(in: .whitespaces).lowercased()
/// }
///
/// // Expands to:
/// private enum normalize_IdempotentTest {
///   @Test static func run() throws {
///     let generator = Gen<String>.string
///     let property = Property(generator: generator) { text in
///       var current = normalize(text)
///       for _ in 1..<2 {
///         current = normalize(current)
///       }
///       let next = normalize(current)
///       return current == next
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
///   - applicationCount: How many times to apply function before final check (default: 2)
///
/// - See Also: ``Deterministic``, ``Property``, ``PropertyConfig``
@attached(peer, names: suffixed(_IdempotentTest))
public macro Idempotent(
  iterations: Int = 100,
  applicationCount: Int = 2
) = #externalMacro(module: "InvariantSwiftMacros", type: "IdempotentMacro")
