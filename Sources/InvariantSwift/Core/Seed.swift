import Foundation

/// A 64-bit deterministic seed enabling reproducible random generation.
///
/// `Seed` provides deterministic randomness for property-based testing, ensuring
/// the same seed always produces identical test sequences. This is essential for:
/// - Reproducing failures for debugging
/// - Regression testing
/// - Creating deterministic test suites
///
/// **Design**:
/// - 64-bit value using unsigned integer representation
/// - Based on LCG (Linear Congruential Generator) for speed and simplicity
/// - Zero values automatically converted to 1 for proper PRNG behavior
/// - Supports splitting for parallel independent generation
///
/// **Key operations**:
/// - `Seed(value:)` - Create with explicit value
/// - `Seed.random` - Generate from system entropy
/// - `seed.next()` - Advance and get next seed
/// - `seed.split()` - Create independent parallel seeds
///
/// **Usage in property testing**:
/// - Record failing test's seed for reproduction
/// - Maintain regression test suites with known-bad seeds
/// - Distribute different seeds to test workers for parallelism
///
/// Mathematical foundation: Implements a LCG-based pseudorandom stream suitable
/// for property-based testing. See [PRNG Design](https://en.wikipedia.org/wiki/Pseudorandom_number_generator)
/// for background.
///
/// - Example:
///   ```swift
///   // Deterministic seed
///   let seed = Seed(value: 42)
///   let (val1, next) = seed.next()  // val1 is deterministic
///
///   // Random seed from system
///   let randomSeed = Seed.random
///
///   // Parallel seeds via splitting
///   let seed1 = seed.split()
///   let seed2 = seed1.split()
///   // seed1 and seed2 produce independent streams
///   ```
///
/// - See Also: ``SeedBasedRandomNumberGenerator``, ``Gen``
public struct Seed: Sendable, Hashable {
  private let state: UInt64

  /// Initializes a seed with an explicit 64-bit value.
  ///
  /// Creates a seed for deterministic random generation. The value becomes the
  /// initial state of a linear congruential generator. Zero values are converted
  /// to 1 internally to ensure proper PRNG behavior (LCGs with zero state never advance).
  ///
  /// - Parameters:
  ///   - value: Initial seed value (UInt64). Zero is converted to 1.
  ///
  /// - Example:
  ///   ```swift
  ///   let seed42 = Seed(value: 42)
  ///   let seedZero = Seed(value: 0)  // Converted to 1 internally
  ///   ```
  public init(value: UInt64) {
    // Ensure non-zero state for proper PRNG behavior
    self.state = value == 0 ? 1 : value
  }

  /// Generates a new seed from system entropy.
  ///
  /// Uses the system's random number generator to create a seed value.
  /// Each call produces a different seed (assuming sufficient system entropy).
  ///
  /// Use this when you don't need reproducibility and want random variation
  /// in each test run.
  ///
  /// - Example:
  ///   ```swift
  ///   let seed = Seed.random
  ///   let anotherSeed = Seed.random  // Different from seed
  ///   ```
  public static var random: Self {
    Self(value: UInt64.random(in: UInt64.min...UInt64.max))
  }

  /// Splits the seed to create an independent parallel seed.
  ///
  /// Generates a new seed from the current one using a different LCG increment,
  /// ensuring the resulting seed produces an independent random sequence.
  /// This is essential for parallel testing where each worker needs
  /// uncorrelated randomness.
  ///
  /// The operation is deterministic: same seed always produces same split.
  ///
  /// - Returns: New independent seed
  ///
  /// - Example:
  ///   ```swift
  ///   let seed = Seed(value: 42)
  ///   let worker1Seed = seed.split()
  ///   let worker2Seed = worker1Seed.split()
  ///   // worker1Seed and worker2Seed produce independent streams
  ///   ```
  ///
  /// - See Also: ``split(count:)`` for creating multiple seeds
  public func split() -> Self {
    let newState = state &* 6_364_136_223_846_793_005 &+ 9_223_372_036_854_775_783
    return Self(value: newState)
  }

  /// Advances the seed and returns both the next random value and next seed.
  ///
  /// Generates a random 64-bit value and the next seed in one operation.
  /// Useful for generators that need both a random value and the next seed
  /// for continued generation.
  ///
  /// The sequence is deterministic: same starting seed produces identical sequences.
  ///
  /// - Returns: Tuple of (generated random value, next seed)
  ///
  /// - Example:
  ///   ```swift
  ///   let seed = Seed(value: 12345)
  ///   let (value1, seed2) = seed.next()       // Get first random value and next seed
  ///   let (value2, seed3) = seed2.next()      // Continue sequence
  ///   // value1 and value2 form a deterministic sequence
  ///   ```
  ///
  /// - See Also: ``generateSequence(count:using:)``
  public func next() -> (value: UInt64, next: Self) {
    let nextState = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return (value: nextState, next: Self(value: nextState))
  }

  /// The raw 64-bit state value of this seed.
  ///
  /// Provides direct access to the underlying state for serialization,
  /// logging, or debugging. Useful for recording seeds that caused test failures.
  ///
  /// - Example:
  ///   ```swift
  ///   let seed = Seed(value: 42)
  ///   print("Failing seed: \(seed.rawValue)")  // Output: "Failing seed: 42"
  ///   ```
  public var rawValue: UInt64 {
    state
  }

  // MARK: - Hashable conformance for deterministic behavior

  public func hash(into hasher: inout Hasher) {
    hasher.combine(state)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.state == rhs.state
  }
}

// MARK: - Integration with RandomNumberGenerator

/// Adapter integrating `Seed` with Swift's `RandomNumberGenerator` protocol.
///
/// `SeedBasedRandomNumberGenerator` wraps a `Seed` value and implements Swift's
/// `RandomNumberGenerator` protocol, allowing use with standard library functions
/// like `Int.random(in:using:)`.
///
/// This enables seamless integration of deterministic `Seed`-based generation
/// with the Swift ecosystem. Each call to `next()` advances the internal seed,
/// producing the next value in the deterministic sequence.
///
/// The generator maintains mutable state (the seed). As it's a value type,
/// you can create independent copies that branch from the same point.
///
/// - Example:
///   ```swift
///   let seed = Seed(value: 42)
///   var rng = SeedBasedRandomNumberGenerator(seed: seed)
///
///   // Use with standard library functions
///   let randomInt = Int.random(in: 0..<100, using: &rng)
///   let randomBool = Bool.random(using: &rng)
///   let randomDouble = Double.random(in: 0..<1, using: &rng)
///
///   // Same seed produces same sequence
///   var rng2 = SeedBasedRandomNumberGenerator(seed: seed)
///   assert(Int.random(in: 0..<100, using: &rng2) == randomInt)
///   ```
///
/// - See Also: ``Seed``, ``Gen``
public struct SeedBasedRandomNumberGenerator: RandomNumberGenerator, Sendable {
  private var seed: Seed

  /// Initializes the RNG with a specific seed.
  ///
  /// - Parameters:
  ///   - seed: Seed value determining the random sequence
  ///
  /// - Example:
  ///   ```swift
  ///   let rng = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
  ///   ```
  public init(seed: Seed) {
    self.seed = seed
  }

  /// Generates the next random 64-bit value.
  ///
  /// Advances the internal seed and returns the generated value.
  /// Called by standard library functions like `Int.random(in:using:)`.
  ///
  /// - Returns: Next random 64-bit value in the sequence
  public mutating func next() -> UInt64 {
    let (value, nextSeed) = seed.next()
    seed = nextSeed
    return value
  }
}

// MARK: - Convenient Extensions

extension Seed {
  /// Creates multiple independent seeds for parallel test execution.
  ///
  /// Generates an array of `count` independent seeds from the current seed,
  /// suitable for distributing to parallel test workers. Each resulting seed
  /// produces an independent random sequence, preventing correlation across workers.
  ///
  /// This is the primary way to set up distributed testing where you want:
  /// - Each worker to have unique randomness
  /// - Complete independence between workers (no overlapping sequences)
  /// - Deterministic assignment (same seed always produces same workers)
  ///
  /// - Parameters:
  ///   - count: Number of seeds to generate. Must be positive.
  ///
  /// - Returns: Array of `count` independent seeds
  ///
  /// - Precondition: `count > 0`
  ///
  /// - Example:
  ///   ```swift
  ///   let masterSeed = Seed(value: 42)
  ///   let workerSeeds = masterSeed.split(count: 4)
  ///
  ///   // Distribute to 4 parallel workers
  ///   DispatchQueue.concurrentPerform(iterations: 4) { index in
  ///       let workerSeed = workerSeeds[index]
  ///       // Run tests with workerSeed...
  ///   }
  ///   ```
  ///
  /// - See Also: ``split()``
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

  /// Generates a sequence of values deterministically using this seed.
  ///
  /// Creates an array of `count` values by repeatedly calling the generator
  /// function with the seed's random number generator. Useful for:
  /// - Creating deterministic test data batches
  /// - Pre-generating known random values
  /// - Debugging generator behavior
  ///
  /// The sequence is completely deterministic: same seed and count produce
  /// identical sequences across all runs and platforms.
  ///
  /// - Parameters:
  ///   - count: Number of values to generate
  ///   - generator: Function generating a value from a RandomNumberGenerator
  ///
  /// - Returns: Array of `count` generated values
  ///
  /// - Example:
  ///   ```swift
  ///   let seed = Seed(value: 42)
  ///   let randomInts = seed.generateSequence(count: 10) { rng in
  ///       Int.random(in: 0..<100, using: &rng)
  ///   }
  ///   // randomInts has 10 deterministic values
  ///
  ///   // Generate the same sequence again
  ///   let sameInts = Seed(value: 42).generateSequence(count: 10) { rng in
  ///       Int.random(in: 0..<100, using: &rng)
  ///   }
  ///   assert(randomInts == sameInts)
  ///   ```
  ///
  /// - See Also: ``SeedBasedRandomNumberGenerator``
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
