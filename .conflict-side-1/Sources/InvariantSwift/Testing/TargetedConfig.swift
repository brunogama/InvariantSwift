// MARK: - ISP-0008: Targeted Property Testing Configuration
// Core configuration types for targeted property testing.

import Foundation

// MARK: - Target Strategy

/// Strategy for balancing multiple optimization targets
public enum TargetStrategy: Sendable, Equatable {
  /// Find inputs optimal in at least one dimension (Pareto frontier)
  case pareto

  /// Combine targets with configurable weights
  case weighted([String: Double])

  /// Prioritize targets in order (first target most important)
  case lexicographic

  /// Default strategy: Pareto optimization
  public static var `default`: Self { .pareto }
}

// MARK: - Mutation Strategy

/// Strategy for mutating elite inputs during targeted testing
public enum MutationStrategy: Sendable, Equatable {
  /// Small random mutations
  case random

  /// Structure-aware mutations
  case structured

  /// Combine multiple strategies
  case combined
}

// MARK: - Target Normalization

/// How to normalize target values for scoring
public enum TargetNormalization: Sendable, Equatable {
  /// Normalize relative to historical best
  case relative

  /// Use absolute values
  case absolute

  /// Use z-score normalization
  case zScore
}

// MARK: - Targeted Configuration

/// Configuration for targeted property testing
public struct TargetedConfig: Sendable {
  /// Fraction of iterations to spend exploring vs exploiting (0.0 - 1.0)
  /// Higher values = more exploration, lower = more exploitation of known good inputs
  public var explorationRate: Double

  /// How many best inputs to keep in the elite pool
  public var elitePoolSize: Int

  /// Mutation strategy for elite inputs
  public var mutationStrategy: MutationStrategy

  /// Target normalization strategy
  public var normalization: TargetNormalization

  /// Strategy for balancing multiple targets
  public var targetStrategy: TargetStrategy

  /// Default configuration
  public static var `default`: Self {
    Self()
  }

  public init(
    explorationRate: Double = 0.3,
    elitePoolSize: Int = 100,
    mutationStrategy: MutationStrategy = .combined,
    normalization: TargetNormalization = .relative,
    targetStrategy: TargetStrategy = .pareto
  ) {
    self.explorationRate = min(1.0, max(0.0, explorationRate))
    self.elitePoolSize = max(1, elitePoolSize)
    self.mutationStrategy = mutationStrategy
    self.normalization = normalization
    self.targetStrategy = targetStrategy
  }
}

// MARK: - Target Record

/// A single recorded target value from a test execution
public struct TargetRecord: Sendable {
  /// The recorded value (normalized to Double)
  public let value: Double

  /// Optional label for the target
  public let label: String?

  /// Whether this is a "toward" target (minimizing distance to goal)
  public let goal: Double?

  /// Computed score (higher is better)
  public var score: Double {
    if let goal {
      // For "toward" targets, score is negative distance to goal
      return -abs(value - goal)
    } else {
      // For maximize targets, score is the value itself
      return value
    }
  }

  public init(value: Double, label: String? = nil, goal: Double? = nil) {
    self.value = value
    self.label = label
    self.goal = goal
  }
}

// MARK: - Scored Input

/// An input with its associated target score
public struct ScoredInput<T: Sendable>: Sendable, Comparable {
  /// The input value
  public let input: T

  /// Aggregate score (higher is better)
  public let score: Double

  /// Individual target records
  public let targets: [TargetRecord]

  /// Iteration number when this input was found
  public let iteration: Int

  public init(input: T, score: Double, targets: [TargetRecord], iteration: Int) {
    self.input = input
    self.score = score
    self.targets = targets
    self.iteration = iteration
  }

  public static func < (lhs: ScoredInput<T>, rhs: ScoredInput<T>) -> Bool {
    lhs.score < rhs.score
  }

  public static func == (lhs: ScoredInput<T>, rhs: ScoredInput<T>) -> Bool {
    lhs.score == rhs.score && lhs.iteration == rhs.iteration
  }
}
