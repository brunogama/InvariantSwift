// GeneratorTestHelpers.swift
// InvariantSwift
//
// Utilities for testing generators.
// Implements Task 1.15 from the roadmap.

import Foundation

// MARK: - Distribution Check Result

/// Result of a distribution check.
public struct DistributionCheckResult: Sendable {
  /// Whether the distribution check passed.
  public let passed: Bool

  /// Observed frequencies for each bucket.
  public let observed: [String: Int]

  /// Expected frequencies (if specified).
  public let expected: [String: Double]?

  /// Chi-squared statistic (if applicable).
  public let chiSquared: Double?

  /// P-value (if applicable).
  public let pValue: Double?

  /// Human-readable summary.
  public let summary: String
}

// MARK: - Shrinking Check Result

/// Result of a shrinking behavior check.
public struct ShrinkingCheckResult: Sendable {
  /// Whether the shrinking check passed.
  public let passed: Bool

  /// Original value that was shrunk.
  public let original: String

  /// Minimal value found.
  public let minimal: String

  /// Number of shrink steps.
  public let shrinkSteps: Int

  /// Whether shrinking converged to expected minimal.
  public let convergedToExpected: Bool

  /// Human-readable summary.
  public let summary: String
}

// MARK: - Determinism Check Result

/// Result of a determinism check.
public struct DeterminismCheckResult: Sendable {
  /// Whether all runs produced identical sequences.
  public let passed: Bool

  /// Seed used for the check.
  public let seed: UInt64

  /// Number of runs compared.
  public let runs: Int

  /// Number of samples per run.
  public let samplesPerRun: Int

  /// First differing position (if any).
  public let firstDifference: Int?

  /// Human-readable summary.
  public let summary: String
}

// MARK: - Generator Test Helpers

/// Utilities for testing generator behavior.
///
/// Provides functions to verify distribution, shrinking, and determinism
/// of generators, which are essential for ensuring quality property-based tests.
///
/// ## Example Usage
///
/// ```swift
/// // Check distribution of a boolean generator
/// let result = GeneratorTestHelpers.checkDistribution(
///     generator: Gen.bool,
///     samples: 10000,
///     buckets: { $0 ? "true" : "false" },
///     expected: ["true": 0.5, "false": 0.5],
///     tolerance: 0.05
/// )
/// assert(result.passed)
///
/// // Check shrinking behavior
/// let shrinkResult = GeneratorTestHelpers.checkShrinking(
///     generator: Gen.int(in: 0...100),
///     failingValue: 50,
///     expectedMinimal: 0
/// )
/// assert(shrinkResult.convergedToExpected)
///
/// // Check determinism
/// let deterResult = GeneratorTestHelpers.checkDeterminism(
///     generator: Gen.int,
///     seed: 12345,
///     samples: 100
/// )
/// assert(deterResult.passed)
/// ```
public enum GeneratorTestHelpers {

  // MARK: - Distribution Checking

  /// Checks that a generator produces values with the expected distribution.
  ///
  /// - Parameters:
  ///   - generator: The generator to test.
  ///   - samples: Number of samples to generate.
  ///   - buckets: Function to categorize values into buckets.
  ///   - expected: Expected proportion for each bucket (optional).
  ///   - tolerance: Allowed deviation from expected proportions.
  ///   - seed: Optional seed for reproducibility.
  /// - Returns: Result of the distribution check.
  public static func checkDistribution<T>(
    generator: Gen<T>,
    samples: Int = 10000,
    buckets: @escaping (T) -> String,
    expected: [String: Double]? = nil,
    tolerance: Double = 0.05,
    seed: Seed? = nil
  ) -> DistributionCheckResult {
    var rng: any RandomNumberGenerator
    if let s = seed {
      rng = SeedBasedRandomNumberGenerator(seed: s)
    } else {
      rng = SystemRandomNumberGenerator()
    }
    var counts: [String: Int] = [:]

    for _ in 0..<samples {
      let value = generator.generate(&rng, Size.medium)
      let bucket = buckets(value)
      counts[bucket, default: 0] += 1
    }

    var passed = true
    var chiSquared: Double = 0

    if let expected = expected {
      for (bucket, expectedProp) in expected {
        let observedCount = counts[bucket, default: 0]
        let observedProp = Double(observedCount) / Double(samples)
        let deviation = abs(observedProp - expectedProp)

        if deviation > tolerance {
          passed = false
        }

        let expectedCount = expectedProp * Double(samples)
        if expectedCount > 0 {
          let diff = Double(observedCount) - expectedCount
          chiSquared += (diff * diff) / expectedCount
        }
      }
    }

    let summary: String
    if passed {
      summary = "Distribution check passed with \(samples) samples across \(counts.count) buckets"
    } else {
      summary =
        "Distribution check failed: observed proportions deviate from expected by more than \(tolerance * 100)%"
    }

    return DistributionCheckResult(
      passed: passed,
      observed: counts,
      expected: expected,
      chiSquared: chiSquared,
      pValue: nil,  // Would need chi-squared CDF for proper p-value
      summary: summary
    )
  }

  /// Checks boolean distribution (special case).
  ///
  /// - Parameters:
  ///   - generator: Boolean generator to test.
  ///   - samples: Number of samples.
  ///   - expectedTrueProportion: Expected proportion of true values.
  ///   - tolerance: Allowed deviation.
  /// - Returns: Distribution check result.
  public static func checkBooleanDistribution(
    generator: Gen<Bool>,
    samples: Int = 10000,
    expectedTrueProportion: Double = 0.5,
    tolerance: Double = 0.05
  ) -> DistributionCheckResult {
    checkDistribution(
      generator: generator,
      samples: samples,
      buckets: { $0 ? "true" : "false" },
      expected: [
        "true": expectedTrueProportion,
        "false": 1 - expectedTrueProportion,
      ],
      tolerance: tolerance
    )
  }

  // MARK: - Shrinking Checking

  /// Checks that a generator shrinks correctly toward a minimal value.
  ///
  /// - Parameters:
  ///   - generator: The generator to test.
  ///   - failingValue: A value that should be shrunk.
  ///   - expectedMinimal: The expected minimal value after shrinking.
  ///   - maxShrinks: Maximum shrink attempts.
  /// - Returns: Result of the shrinking check.
  public static func checkShrinking<T: Equatable>(
    generator: Gen<T>,
    failingValue: T,
    expectedMinimal: T,
    maxShrinks: Int = 1000
  ) -> ShrinkingCheckResult {
    var current = failingValue
    var steps = 0

    for _ in 0..<maxShrinks {
      let candidates = generator.shrink.shrink(current)
      guard let better = candidates.first else { break }
      current = better
      steps += 1
    }

    let converged = current == expectedMinimal

    let summary: String
    if converged {
      summary = "Shrinking converged to expected minimal in \(steps) steps"
    } else {
      summary = "Shrinking stopped at '\(current)' but expected '\(expectedMinimal)'"
    }

    return ShrinkingCheckResult(
      passed: converged,
      original: String(describing: failingValue),
      minimal: String(describing: current),
      shrinkSteps: steps,
      convergedToExpected: converged,
      summary: summary
    )
  }

  /// Checks that shrinking terminates.
  ///
  /// - Parameters:
  ///   - generator: The generator to test.
  ///   - value: Starting value for shrinking.
  ///   - maxSteps: Maximum allowed steps before considering it infinite.
  /// - Returns: Whether shrinking terminated within the limit.
  public static func checkShrinkingTerminates<T>(
    generator: Gen<T>,
    value: T,
    maxSteps: Int = 10000
  ) -> Bool {
    var current = value

    for _ in 0..<maxSteps {
      let candidates = generator.shrink.shrink(current)
      guard let better = candidates.first else { return true }
      current = better
    }

    return false
  }

  // MARK: - Determinism Checking

  /// Checks that a generator produces identical sequences with the same seed.
  ///
  /// - Parameters:
  ///   - generator: The generator to test.
  ///   - seed: The seed to use.
  ///   - samples: Number of samples to compare.
  ///   - runs: Number of runs to compare (default: 3).
  /// - Returns: Result of the determinism check.
  public static func checkDeterminism<T: Equatable>(
    generator: Gen<T>,
    seed: UInt64,
    samples: Int = 100,
    runs: Int = 3
  ) -> DeterminismCheckResult {
    var sequences: [[T]] = []

    for _ in 0..<runs {
      var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: seed))
      var sequence: [T] = []

      for _ in 0..<samples {
        sequence.append(generator.generate(&rng, Size.medium))
      }

      sequences.append(sequence)
    }

    // Compare all sequences
    var firstDifference: Int?
    var allEqual = true

    outer: for i in 0..<samples {
      let reference = sequences[0][i]
      for seq in sequences.dropFirst() {
        if seq[i] != reference {
          firstDifference = i
          allEqual = false
          break outer
        }
      }
    }

    let summary: String
    if allEqual {
      summary =
        "Determinism check passed: \(runs) runs with seed \(seed) produced identical sequences"
    } else {
      summary = "Determinism check failed: sequences diverged at position \(firstDifference ?? -1)"
    }

    return DeterminismCheckResult(
      passed: allEqual,
      seed: seed,
      runs: runs,
      samplesPerRun: samples,
      firstDifference: firstDifference,
      summary: summary
    )
  }

  // MARK: - Coverage Checking

  /// Checks that a generator covers expected values.
  ///
  /// - Parameters:
  ///   - generator: The generator to test.
  ///   - samples: Number of samples to generate.
  ///   - expectedValues: Values that should appear.
  ///   - seed: Optional seed.
  /// - Returns: Set of expected values that were found.
  public static func checkCoverage<T: Hashable>(
    generator: Gen<T>,
    samples: Int = 10000,
    expectedValues: Set<T>,
    seed: Seed? = nil
  ) -> Set<T> {
    var rng: any RandomNumberGenerator
    if let s = seed {
      rng = SeedBasedRandomNumberGenerator(seed: s)
    } else {
      rng = SystemRandomNumberGenerator()
    }
    var found: Set<T> = []

    for _ in 0..<samples {
      let value = generator.generate(&rng, Size.medium)
      if expectedValues.contains(value) {
        found.insert(value)
      }

      if found == expectedValues {
        break
      }
    }

    return found
  }

  /// Checks that generated values satisfy a constraint.
  ///
  /// - Parameters:
  ///   - generator: The generator to test.
  ///   - samples: Number of samples.
  ///   - constraint: The constraint to check.
  /// - Returns: Tuple of (passed, first failing value if any).
  public static func checkConstraint<T>(
    generator: Gen<T>,
    samples: Int = 1000,
    constraint: (T) -> Bool
  ) -> (passed: Bool, failingValue: T?) {
    var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()

    for _ in 0..<samples {
      let value = generator.generate(&rng, Size.medium)
      if !constraint(value) {
        return (false, value)
      }
    }

    return (true, nil)
  }
}
