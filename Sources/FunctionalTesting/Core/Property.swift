import Foundation

/// Result of running a property test
public enum PropertyResult<T>: Sendable where T: Sendable {
  case success(iterations: Int)
  case failure(counterexample: T, iterations: Int, shrunk: T)
  case gaveUp(discarded: Int, iterations: Int)
}

/// Property represents a testable proposition over generated values
public struct Property<T>: @unchecked Sendable {
  public let generator: Gen<T>
  public let predicate: (T) -> Bool

  public init(generator: Gen<T>, predicate: @escaping (T) -> Bool) {
    self.generator = generator
    self.predicate = predicate
  }

  /// Convenience initializer for properties with assumptions
  public init(
    generator: Gen<T>,
    assumption: @escaping (T) -> Bool = { _ in true },
    predicate: @escaping (T) -> Bool
  ) {
    self.generator = generator.suchThat(assumption)
    self.predicate = predicate
  }
}

/// Configuration for property testing
public struct PropertyConfig: Sendable {
  public let iterations: Int
  public let maxShrinks: Int
  public let maxDiscarded: Int
  public let seed: Seed?

  public init(
    iterations: Int = 100,
    maxShrinks: Int = 1000,
    maxDiscarded: Int = 1000,
    seed: Seed? = nil
  ) {
    self.iterations = max(1, iterations)
    self.maxShrinks = max(0, maxShrinks)
    self.maxDiscarded = max(0, maxDiscarded)
    self.seed = seed
  }

  public static let `default` = PropertyConfig()
}

/// Thread-safe random number generator wrapper
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
  private var state: UInt64

  public init(seed: UInt64) {
    self.state = seed == 0 ? 1 : seed
  }

  public mutating func next() -> UInt64 {
    // Linear congruential generator (simple but effective for testing)
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

/// Actor for thread-safe property testing execution
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor PropertyRunner {
  private var rng: any RandomNumberGenerator

  public init(seed: Seed? = nil) {
    if let seed = seed {
      self.rng = SeedBasedRandomNumberGenerator(seed: seed)
    } else {
      self.rng = SystemRandomNumberGenerator()
    }
  }

  /// Run a property test with the given configuration
  public func runProperty<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    for iteration in 0..<config.iterations {
      let size = Size(value: min(iteration, 100))
      let testCase = property.generator.generate(&rng, size)

      // Check if the property holds
      if !property.predicate(testCase) {
        // Property failed - begin shrinking
        let shrunkCase = shrinkFailure(
          testCase,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: iteration + 1,
          shrunk: shrunkCase
        )
      }
    }

    return .success(iterations: config.iterations)
  }

  /// Shrink a failing test case to find the minimal counterexample
  private func shrinkFailure<T>(
    _ failingCase: T,
    property: Property<T>,
    maxShrinks: Int
  ) -> T {
    var current = failingCase
    var shrinkAttempts = 0

    while shrinkAttempts < maxShrinks {
      let candidates = property.generator.shrink.shrink(current)

      // Find the first shrunk value that still fails the property
      let nextFailure = candidates.first { candidate in
        !property.predicate(candidate)
      }

      if let nextFailure = nextFailure {
        current = nextFailure
        shrinkAttempts += 1
      } else {
        // No more shrinking possible
        break
      }
    }

    return current
  }
}

// MARK: - Convenience Extensions

extension Property {
  /// Create a property that checks a boolean condition
  public static func check(
    _ generator: Gen<T>,
    _ condition: @escaping (T) -> Bool
  ) -> Property<T> {
    Property(generator: generator, predicate: condition)
  }

  /// Create a property with an implication (assumption -> conclusion)
  public static func implies(
    _ generator: Gen<T>,
    assumption: @escaping (T) -> Bool,
    conclusion: @escaping (T) -> Bool
  ) -> Property<T> {
    Property(
      generator: generator,
      predicate: { value in
        !assumption(value) || conclusion(value)
      }
    )
  }
}

// MARK: - Property Combinators

extension Property {
  /// Combine two properties with logical AND
  public func and<U>(_ other: Property<U>) -> Property<(T, U)> {
    Property<(T, U)>(
      generator: self.generator.zip(other.generator),
      predicate: { pair in
        self.predicate(pair.0) && other.predicate(pair.1)
      }
    )
  }

  /// Combine two properties with logical OR
  public func or<U>(_ other: Property<U>) -> Property<(T, U)> {
    Property<(T, U)>(
      generator: self.generator.zip(other.generator),
      predicate: { pair in
        self.predicate(pair.0) || other.predicate(pair.1)
      }
    )
  }
}

// MARK: - Synchronous Property Checking

/// Synchronous property checking for compatibility
public struct PropertyChecker {
  public static func check<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    var rng: any RandomNumberGenerator

    if let seed = config.seed {
      rng = SeedBasedRandomNumberGenerator(seed: seed)
    } else {
      rng = SystemRandomNumberGenerator()
    }

    for iteration in 0..<config.iterations {
      let size = Size(value: min(iteration, 100))
      let testCase = property.generator.generate(&rng, size)

      if !property.predicate(testCase) {
        let shrunkCase = shrinkFailureSync(
          testCase,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: iteration + 1,
          shrunk: shrunkCase
        )
      }
    }

    return .success(iterations: config.iterations)
  }

  private static func shrinkFailureSync<T>(
    _ failingCase: T,
    property: Property<T>,
    maxShrinks: Int
  ) -> T {
    var current = failingCase
    var shrinkAttempts = 0

    while shrinkAttempts < maxShrinks {
      let candidates = property.generator.shrink.shrink(current)

      let nextFailure = candidates.first { candidate in
        !property.predicate(candidate)
      }

      if let nextFailure = nextFailure {
        current = nextFailure
        shrinkAttempts += 1
      } else {
        break
      }
    }

    return current
  }
}

// MARK: - Coverage-Guided Property Testing Extensions

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PropertyRunner {
  /// Run property with coverage guidance
  public func runPropertyWithCoverageGuidance<T>(
    _ property: Property<T>,
    collector: CoverageCollector,
    config: PropertyConfig = .default,
    coverageConfig: CoverageConfig = .default,
    coverageStrategy: CoverageStrategy = .frequency
  ) async -> (PropertyResult<T>, CoverageReport) {

    // Phase 1: Baseline execution to establish initial coverage
    let baselineIterations = min(20, config.iterations / 5)
    let baselineResult = self.runProperty(
      property,
      config: PropertyConfig(
        iterations: baselineIterations,
        maxShrinks: config.maxShrinks,
        maxDiscarded: config.maxDiscarded,
        seed: config.seed
      )
    )

    // Record baseline execution
    let baselineCoverage = await collector.currentBudget()
    let initialCoverage = baselineCoverage.coveragePercentage

    // Phase 2: Coverage-guided execution
    let remainingIterations = config.iterations - baselineIterations
    var finalResult = baselineResult

    if remainingIterations > 0 && !baselineResult.isFailure {
      let currentBudget = await collector.currentBudget()
      let guidedProperty = property.withCoverageGuidance(
        budget: currentBudget,
        strategy: coverageStrategy,
        config: coverageConfig
      )

      let guidedResult = self.runProperty(
        guidedProperty,
        config: PropertyConfig(
          iterations: remainingIterations,
          maxShrinks: config.maxShrinks,
          maxDiscarded: config.maxDiscarded,
          seed: config.seed
        )
      )

      // Use the guided result if baseline succeeded
      if case .success = baselineResult {
        finalResult = guidedResult
      }
    }

    // Generate coverage report
    let finalBudget = await collector.currentBudget()
    let finalCoverage = finalBudget.coveragePercentage
    let report = CoverageReport(
      initialCoverage: initialCoverage,
      finalCoverage: finalCoverage,
      improvement: finalCoverage - initialCoverage,
      executionCount: config.iterations,
      uncoveredSymbols: Array(finalBudget.uncoveredSymbols).sorted()
    )

    return (finalResult, report)
  }

  /// Run property with automatic coverage tracking
  public func runPropertyWithCoverageTracking<T>(
    _ property: Property<T>,
    knownSymbols: Set<String> = [],
    config: PropertyConfig = .default,
    coverageConfig: CoverageConfig = .default
  ) async -> (PropertyResult<T>, CoverageReport) {

    let collector = CoverageCollector(config: coverageConfig)

    // Add known symbols if provided
    if !knownSymbols.isEmpty {
      await collector.addKnownSymbols(knownSymbols)
    }

    return await runPropertyWithCoverageGuidance(
      property,
      collector: collector,
      config: config,
      coverageConfig: coverageConfig
    )
  }
}

extension PropertyResult {
  /// Check if the property result represents a failure
  public var isFailure: Bool {
    switch self {
    case .failure:
      return true
    case .success, .gaveUp:
      return false
    }
  }

  /// Check if the property result represents success
  public var isSuccess: Bool {
    switch self {
    case .success:
      return true
    case .failure, .gaveUp:
      return false
    }
  }
}
