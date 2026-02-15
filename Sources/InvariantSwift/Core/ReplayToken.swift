import Foundation

// MARK: - ReplayToken (S031)

/// A token capturing all information needed to reproduce a property test failure.
///
/// `ReplayToken` enables exact failure reproduction across machines and runs.
/// It encodes the seed, configuration, and optionally the minimal counterexample
/// in a copy-pasteable format.
///
/// - Example:
///   ```swift
///   // From a failure
///   let token = ReplayToken(
///     seed: failingSeed,
///     iterations: 100,
///     size: 50,
///     maxDiscarded: 500
///   )
///
///   // Encode for copy-paste
///   let encoded = token.encode()
///   // Use encoded token for replay
///
///   // Parse and replay
///   if let parsed = ReplayToken.parse(encoded) {
///     // Re-run with parsed.seed, parsed.config
///   }
///   ```
///
/// - See Also: ``PropertyResult``, ``Seed``
public struct ReplayToken: Sendable, Equatable, Codable {
  /// The seed that was used for the failing test run.
  public let seed: UInt64

  /// Number of iterations configured.
  public let iterations: Int

  /// Size parameter for generation.
  public let size: Int

  /// Maximum discarded values before giving up.
  public let maxDiscarded: Int

  /// Optional serialized counterexample (for types that support it).
  public let counterexample: String?

  /// Creates a replay token from test configuration.
  ///
  /// - Parameters:
  ///   - seed: The seed value that produced the failure
  ///   - iterations: Number of iterations configured
  ///   - size: Size parameter for generation
  ///   - maxDiscarded: Maximum discarded limit
  ///   - counterexample: Optional serialized counterexample
  public init(
    seed: UInt64,
    iterations: Int = 100,
    size: Int = 100,
    maxDiscarded: Int = 500,
    counterexample: String? = nil
  ) {
    self.seed = seed
    self.iterations = iterations
    self.size = size
    self.maxDiscarded = maxDiscarded
    self.counterexample = counterexample
  }

  /// Creates a replay token from a Seed and PropertyConfig.
  ///
  /// - Parameters:
  ///   - seed: The Seed struct
  ///   - config: The PropertyConfig used
  ///   - counterexample: Optional serialized counterexample
  public init(seed: Seed, config: PropertyConfig, counterexample: String? = nil) {
    self.seed = seed.rawValue
    self.iterations = config.iterations
    self.size = 100  // Default size, could be extracted from config if available
    self.maxDiscarded = config.maxDiscarded
    self.counterexample = counterexample
  }

  // MARK: - Encoding

  /// Encodes the token to a base64url JSON string.
  ///
  /// The encoded string is safe to copy-paste into test code or command lines.
  ///
  /// - Returns: Base64url-encoded JSON representation
  public func encode() -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    guard let data = try? encoder.encode(self) else {
      // Fallback to simple format
      return "seed=\(seed)"
    }

    // Use base64url encoding (URL-safe variant)
    return data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  /// Parses a replay token from an encoded string.
  ///
  /// Accepts either base64url JSON format or simple `seed=N` format.
  ///
  /// - Parameter encoded: The encoded token string
  /// - Returns: Parsed ReplayToken, or nil if parsing fails
  public static func parse(_ encoded: String) -> Self? {
    // Try simple format first: "seed=12345"
    if encoded.hasPrefix("seed=") {
      let seedString = String(encoded.dropFirst(5))
      if let seedValue = UInt64(seedString) {
        return Self(seed: seedValue)
      }
    }

    // Try base64url JSON format
    var base64 =
      encoded
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")

    // Add padding if needed
    let paddingNeeded = (4 - base64.count % 4) % 4
    base64 += String(repeating: "=", count: paddingNeeded)

    guard let data = Data(base64Encoded: base64) else {
      return nil
    }

    let decoder = JSONDecoder()
    return try? decoder.decode(Self.self, from: data)
  }

  // MARK: - Pretty Printing

  /// Returns a human-readable description of the token.
  public var description: String {
    var parts: [String] = ["seed: \(seed)"]
    parts.append("iterations: \(iterations)")
    parts.append("maxDiscarded: \(maxDiscarded)")
    if let ce = counterexample {
      parts.append("counterexample: \(ce)")
    }
    return "ReplayToken(\(parts.joined(separator: ", ")))"
  }

  /// Returns a copy-paste snippet for re-running with this token.
  public var replaySnippet: String {
    """
    // Replay with:
    let config = PropertyConfig(
      iterations: \(iterations),
      maxDiscarded: \(maxDiscarded),
      seed: Seed(value: \(seed))
    )
    """
  }

  /// Returns comprehensive reproduction instructions.
  ///
  /// Provides three options for reproducing the failure:
  /// 1. Environment variable (recommended for CI)
  /// 2. Inline configuration
  /// 3. Parse replay token
  public var fullReproductionInstructions: String {
    """
    ━━━ REPRODUCTION ━━━

    Option 1: Environment variable (recommended for CI)
    $ INVARIANT_SEED=\(seed) swift test --filter YourTestName

    Option 2: Inline configuration
    let config = PropertyConfig(
      iterations: \(iterations),
      maxDiscarded: \(maxDiscarded),
      seed: Seed(value: \(seed))
    )

    Option 3: Parse replay token
    let token = ReplayToken.parse(\"\(encode())\")!
    let config = token.toConfig()
    """
  }

  // MARK: - Conversion

  /// Converts this replay token to a PropertyConfig for re-running.
  ///
  /// - Returns: A PropertyConfig using the token's stored configuration values
  ///
  /// - Example:
  ///   ```swift
  ///   let token = ReplayToken.parse(encodedString)!
  ///   let config = token.toConfig()
  ///   let runner = PropertyRunner(seed: Seed(value: token.seed))
  ///   let result = runner.runProperty(property, config: config)
  ///   ```
  public func toConfig() -> PropertyConfig {
    PropertyConfig(
      iterations: iterations,
      maxShrinks: 1000,  // Default shrink budget
      maxDiscarded: maxDiscarded,
      seed: Seed(value: seed)
    )
  }
}

// MARK: - Integration with PropertyResult

extension ReplayToken {
  /// Creates a replay token from a property test failure result.
  ///
  /// - Parameters:
  ///   - result: The failing property result
  ///   - config: The configuration that was used
  /// - Returns: ReplayToken for reproducing the failure, or nil if result wasn't a failure
  public static func from<T>(
    _ result: PropertyResult<T>,
    config: PropertyConfig
  ) -> ReplayToken? {
    switch result {
    case .failure(_, _, _, _, let seed):
      return ReplayToken(seed: seed, config: config)

    case .success, .gaveUp:
      return nil
    }
  }
}
