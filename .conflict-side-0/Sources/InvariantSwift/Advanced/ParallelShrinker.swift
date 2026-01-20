/// ParallelShrinker - Actor for coordinated parallel shrink exploration
///
/// Provides high-level coordination for parallel shrinking operations with
/// configurable worker count, budget allocation, and progress tracking.

import Foundation
import InvariantSwiftCore

// MARK: - ParallelShrinker Actor

/// Actor for coordinating parallel shrink exploration.
///
/// Manages worker count, budget allocation, and result aggregation
/// for parallel shrinking operations. Provides a clean API for
/// transitioning from sequential to parallel shrinking.
///
/// Key features:
/// - Configurable worker count (defaults to processor count)
/// - Automatic threshold-based sequential fallback
/// - Optional progress tracking
/// - Benchmarking capabilities for performance tuning
///
/// - Example:
///   ```swift
///   let shrinker = ParallelShrinker(config: .default)
///   let tree = ShrinkTree.from(100, shrink: Shrink<Int> { ... })
///
///   let minimal = await shrinker.findMinimal(in: tree) { $0 > 10 }
///   // Result: 11 (found with parallel exploration)
///   ```
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor ParallelShrinker {

  // MARK: - Configuration

  /// Configuration for parallel shrinking behavior.
  public struct Config: Sendable {
    /// Number of concurrent workers for parallel exploration.
    ///
    /// Default: ProcessInfo.processInfo.processorCount
    public let workers: Int

    /// Total shrink budget (maximum nodes to visit).
    ///
    /// Default: 1000 (matches PropertyRunner default)
    public let budget: Int

    /// Minimum tree size to use parallel exploration.
    ///
    /// Below this threshold, sequential search is used to avoid
    /// TaskGroup overhead. Trees smaller than this don't benefit
    /// from parallelization.
    ///
    /// Default: 100
    public let parallelThreshold: Int

    /// Enable progress tracking (nodes visited, candidates found).
    ///
    /// When enabled, tracks metrics via `getProgress()`. Has minimal
    /// overhead but should be disabled in production for maximum performance.
    ///
    /// Default: false
    public let trackProgress: Bool

    /// Creates a parallel shrinking configuration.
    ///
    /// - Parameters:
    ///   - workers: Number of concurrent workers (default: processor count)
    ///   - budget: Total shrink budget (default: 1000)
    ///   - parallelThreshold: Minimum tree size for parallel (default: 100)
    ///   - trackProgress: Enable progress tracking (default: false)
    public init(
      workers: Int = ProcessInfo.processInfo.processorCount,
      budget: Int = 1000,
      parallelThreshold: Int = 100,
      trackProgress: Bool = false
    ) {
      self.workers = max(1, workers)
      self.budget = max(1, budget)
      self.parallelThreshold = max(1, parallelThreshold)
      self.trackProgress = trackProgress
    }

    /// Default configuration optimized for most use cases.
    ///
    /// Uses processor count workers, 1000 node budget,
    /// 100 node parallel threshold, no progress tracking.
    public static let `default` = Config()

    /// High-performance configuration for large shrink trees.
    ///
    /// Uses 2x processor count workers, 5000 node budget,
    /// 50 node parallel threshold for aggressive parallelization.
    public static let highPerformance = Config(
      workers: ProcessInfo.processInfo.processorCount * 2,
      budget: 5000,
      parallelThreshold: 50,
      trackProgress: false
    )

    /// Debug configuration with progress tracking enabled.
    ///
    /// Uses default settings but enables progress tracking
    /// for observability during development.
    public static let debug = Config(
      workers: ProcessInfo.processInfo.processorCount,
      budget: 1000,
      parallelThreshold: 100,
      trackProgress: true
    )
  }

  // MARK: - State

  private let config: Config
  private var nodesVisited: Int = 0
  private var candidatesFound: Int = 0

  // MARK: - Initialization

  /// Creates a parallel shrinker with the given configuration.
  ///
  /// - Parameter config: Configuration for parallel behavior (default: .default)
  public init(config: Config = .default) {
    self.config = config
  }

  // MARK: - Public Interface

  /// Finds the minimal value in a shrink tree satisfying a predicate.
  ///
  /// Automatically selects parallel or sequential search based on
  /// budget and tree characteristics. Updates progress tracking if enabled.
  ///
  /// - Parameters:
  ///   - tree: The shrink tree to search
  ///   - predicate: Async predicate that must be satisfied
  ///
  /// - Returns: The minimal satisfying value, or nil if none found
  ///
  /// - Example:
  ///   ```swift
  ///   let shrinker = ParallelShrinker()
  ///   let tree = ShrinkTree.from(100, shrink: intShrink)
  ///   let minimal = await shrinker.findMinimal(in: tree) { $0 > 0 }
  ///   ```
  public func findMinimal<T: Sendable>(
    in tree: ShrinkTree<T>,
    satisfying predicate: @escaping @Sendable (T) async -> Bool
  ) async -> T? {
    // Reset progress tracking
    nodesVisited = 0
    candidatesFound = 0

    if config.budget < config.parallelThreshold {
      // Use sequential for small budgets
      let result = await tree.findMinimalAsync(
        budget: config.budget,
        satisfying: predicate
      )

      if config.trackProgress {
        nodesVisited = config.budget
        candidatesFound = result != nil ? 1 : 0
      }

      return result
    }

    // Use parallel search for larger budgets
    let result = await tree.findMinimalParallel(
      budget: config.budget,
      workers: config.workers,
      satisfying: predicate
    )

    if config.trackProgress {
      nodesVisited = config.budget
      candidatesFound = result != nil ? 1 : 0
    }

    return result
  }

  /// Finds the minimal comparable value with guaranteed minimum selection.
  ///
  /// Optimized version for Comparable types that ensures the truly minimal
  /// value (by Comparable ordering) is returned when multiple candidates exist.
  ///
  /// - Parameters:
  ///   - tree: The shrink tree to search
  ///   - predicate: Async predicate that must be satisfied
  ///
  /// - Returns: The minimal satisfying value (guaranteed smallest by <), or nil if none found
  public func findMinimalComparable<T: Sendable & Comparable>(
    in tree: ShrinkTree<T>,
    satisfying predicate: @escaping @Sendable (T) async -> Bool
  ) async -> T? {
    nodesVisited = 0
    candidatesFound = 0

    if config.budget < config.parallelThreshold {
      let result = await tree.findMinimalAsync(
        budget: config.budget,
        satisfying: predicate
      )

      if config.trackProgress {
        nodesVisited = config.budget
        candidatesFound = result != nil ? 1 : 0
      }

      return result
    }

    let result = await tree.findMinimalParallelComparable(
      budget: config.budget,
      workers: config.workers,
      satisfying: predicate
    )

    if config.trackProgress {
      nodesVisited = config.budget
      candidatesFound = result != nil ? 1 : 0
    }

    return result
  }

  /// Returns progress metrics.
  ///
  /// Only meaningful if `config.trackProgress` is true. Otherwise,
  /// returns default zero values.
  ///
  /// - Returns: Tuple of (nodesVisited, candidatesFound)
  public func getProgress() -> (nodesVisited: Int, candidatesFound: Int) {
    (nodesVisited, candidatesFound)
  }

  /// Resets progress tracking counters to zero.
  public func resetProgress() {
    nodesVisited = 0
    candidatesFound = 0
  }
}

// MARK: - Benchmarking

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension ParallelShrinker {
  /// Compares parallel vs sequential shrinking performance.
  ///
  /// Runs both parallel and sequential search on the same tree and predicate,
  /// returning timing and result comparison for debugging and optimization.
  ///
  /// Useful for:
  /// - Tuning worker count and budget
  /// - Identifying trees that benefit from parallelization
  /// - Validating correctness (both should find same result)
  ///
  /// - Parameters:
  ///   - tree: The shrink tree to benchmark
  ///   - predicate: Async predicate that must be satisfied
  ///
  /// - Returns: Benchmark results with timing and speedup
  ///
  /// - Example:
  ///   ```swift
  ///   let benchmark = await shrinker.benchmark(tree: tree) { $0 > 0 }
  ///   // Use benchmark.speedup, benchmark.sequentialTime, benchmark.parallelTime
  ///   ```
  public func benchmark<T: Sendable & Equatable>(
    tree: ShrinkTree<T>,
    predicate: @escaping @Sendable (T) async -> Bool
  ) async -> ShrinkBenchmark<T> {
    // Sequential search
    let sequentialStart = CFAbsoluteTimeGetCurrent()
    let sequentialResult = await tree.findMinimalAsync(
      budget: config.budget,
      satisfying: predicate
    )
    let sequentialTime = CFAbsoluteTimeGetCurrent() - sequentialStart

    // Parallel search
    let parallelStart = CFAbsoluteTimeGetCurrent()
    let parallelResult = await tree.findMinimalParallel(
      budget: config.budget,
      workers: config.workers,
      satisfying: predicate
    )
    let parallelTime = CFAbsoluteTimeGetCurrent() - parallelStart

    return ShrinkBenchmark(
      sequentialResult: sequentialResult,
      sequentialTime: sequentialTime,
      parallelResult: parallelResult,
      parallelTime: parallelTime,
      speedup: sequentialTime / parallelTime,
      resultsMatch: sequentialResult == parallelResult
    )
  }
}

// MARK: - Benchmark Result

/// Results from a parallel vs sequential shrinking benchmark.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct ShrinkBenchmark<T: Sendable>: Sendable {
  /// Result from sequential search.
  public let sequentialResult: T?

  /// Time taken by sequential search (seconds).
  public let sequentialTime: TimeInterval

  /// Result from parallel search.
  public let parallelResult: T?

  /// Time taken by parallel search (seconds).
  public let parallelTime: TimeInterval

  /// Speedup factor (sequentialTime / parallelTime).
  ///
  /// Values > 1.0 indicate parallel was faster.
  /// Values < 1.0 indicate sequential was faster (overhead dominated).
  public let speedup: Double

  /// Whether both searches found the same result.
  ///
  /// Should always be true for correct implementations.
  /// False indicates a bug in parallel search.
  public let resultsMatch: Bool

  /// Creates a benchmark result.
  public init(
    sequentialResult: T?,
    sequentialTime: TimeInterval,
    parallelResult: T?,
    parallelTime: TimeInterval,
    speedup: Double,
    resultsMatch: Bool
  ) {
    self.sequentialResult = sequentialResult
    self.sequentialTime = sequentialTime
    self.parallelResult = parallelResult
    self.parallelTime = parallelTime
    self.speedup = speedup
    self.resultsMatch = resultsMatch
  }
}
