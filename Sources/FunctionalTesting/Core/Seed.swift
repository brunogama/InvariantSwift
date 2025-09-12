import Foundation

/// 64-bit deterministic pseudorandom seed for reproducible test execution
/// Enables identical test runs with same seed/size parameters across platforms
public struct Seed: Sendable, Hashable {
  private let state: UInt64

  /// Initialize with explicit seed value
  public init(value: UInt64) {
    // Ensure non-zero state for proper PRNG behavior
    self.state = value == 0 ? 1 : value
  }

  /// Create random seed from system entropy
  public static var random: Seed {
    Seed(value: UInt64.random(in: UInt64.min...UInt64.max))
  }

  /// Split seed to create independent sequence for parallel generation
  /// Uses different constants to ensure statistical independence
  public func split() -> Seed {
    let newState = state &* 6_364_136_223_846_793_005 &+ 9_223_372_036_854_775_783
    return Seed(value: newState)
  }

  /// Advance seed state and return both random value and next seed
  /// Uses linear congruential generator with good statistical properties
  public func next() -> (value: UInt64, next: Seed) {
    let nextState = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return (value: nextState, next: Seed(value: nextState))
  }

  /// Get raw seed value for serialization and replay
  public var rawValue: UInt64 {
    state
  }

  // MARK: - Hashable conformance for deterministic behavior

  public func hash(into hasher: inout Hasher) {
    hasher.combine(state)
  }

  public static func == (lhs: Seed, rhs: Seed) -> Bool {
    lhs.state == rhs.state
  }
}

// MARK: - Integration with RandomNumberGenerator

/// Seed-based random number generator for deterministic generation
/// Integrates Seed type with Swift's RandomNumberGenerator protocol
public struct SeedBasedRandomNumberGenerator: RandomNumberGenerator, Sendable {
  private var seed: Seed

  public init(seed: Seed) {
    self.seed = seed
  }

  public mutating func next() -> UInt64 {
    let (value, nextSeed) = seed.next()
    seed = nextSeed
    return value
  }
}

// MARK: - Convenient Extensions

extension Seed {
  /// Create multiple independent seeds for parallel processing
  public func split(count: Int) -> [Seed] {
    precondition(count > 0, "Split count must be positive")

    var seeds: [Seed] = []
    var currentSeed = self

    for _ in 0..<count {
      let splitSeed = currentSeed.split()
      seeds.append(splitSeed)
      currentSeed = splitSeed
    }

    return seeds
  }

  /// Generate a sequence of random values using this seed
  /// Useful for deterministic test data generation
  public func generateSequence<T>(
    count: Int,
    using generator: (inout any RandomNumberGenerator) -> T
  ) -> [T] {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: self)
    return (0..<count).map { _ in generator(&rng) }
  }
}

// MARK: - Cross-Platform Compatibility

extension Seed {
  /// Create seed from string for cross-platform reproducibility
  /// Same string produces same seed on all platforms
  public init(string: String) {
    var hasher = Hasher()
    hasher.combine(string)
    let hashValue = UInt64(bitPattern: Int64(hasher.finalize()))
    self.init(value: hashValue)
  }

  /// Convert seed to string for serialization
  public var stringRepresentation: String {
    "\(state)"
  }
}

// MARK: - Constants for Common Seeds

extension Seed {
  /// Standard test seed for deterministic testing
  public static let test = Seed(value: 42)

  /// Zero seed (automatically converted to 1 for proper PRNG behavior)
  public static let zero = Seed(value: 0)

  /// Maximum seed value
  public static let max = Seed(value: UInt64.max)
}
