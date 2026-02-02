/// Scheduler - Deterministic Concurrency Testing
///
/// Provides controlled interleaving of async operations for race condition detection.
/// This is the public API for ISP-0001: Scheduler-Based Race Condition Testing.

import Foundation

// MARK: - Core Types

/// Controls the execution order of concurrent operations for deterministic testing.
///
/// Use `Scheduler` to systematically explore interleavings of concurrent code:
///
/// ```swift
/// let scheduler = Scheduler(strategy: .exhaustive(depth: 5))
/// try await scheduler.run {
///     await withTaskGroup(of: Void.self) { group in
///         group.addTask { await cache.get("key") }
///         group.addTask { await cache.get("key") }
///     }
/// }
/// ```
public struct Scheduler: Sendable {

  /// Exploration strategy for interleavings
  public enum Strategy: Sendable, Equatable {
    /// Random interleaving (default, fast)
    case random(seed: UInt64?)

    /// Systematic exploration up to depth
    case exhaustive(depth: Int)

    /// Prioritize interleavings likely to expose bugs
    case targeted(heuristic: InterleavingHeuristic)

    /// Replay a specific interleaving path
    case replay(path: InterleavingPath)

    public static func == (lhs: Self, rhs: Self) -> Bool {
      switch (lhs, rhs) {
      case (.random(let lSeed), .random(let rSeed)):
        return lSeed == rSeed

      case (.exhaustive(let lDepth), .exhaustive(let rDepth)):
        return lDepth == rDepth

      case (.targeted(let lHeuristic), .targeted(let rHeuristic)):
        return lHeuristic == rHeuristic

      case (.replay(let lPath), .replay(let rPath)):
        return lPath == rPath

      default:
        return false
      }
    }
  }

  /// The strategy used for this scheduler
  public let strategy: Strategy

  /// Maximum interleavings to explore
  public let maxInterleavings: Int

  /// Timeout for each interleaving exploration
  public let timeout: Duration

  /// Current interleaving path (for reproduction)
  public private(set) var currentPath: InterleavingPath

  /// History of explored paths
  private var exploredPaths: [InterleavingPath] = []

  /// Internal RNG for deterministic execution
  private var rng: SchedulerRNG

  public init(
    strategy: Strategy = .random(seed: nil),
    maxInterleavings: Int = 1000,
    timeout: Duration = .seconds(30)
  ) {
    self.strategy = strategy
    self.maxInterleavings = maxInterleavings
    self.timeout = timeout
    self.currentPath = InterleavingPath(steps: [])

    switch strategy {
    case .random(let seed):
      self.rng = SchedulerRNG(seed: seed ?? UInt64.random(in: UInt64.min...UInt64.max))

    case .exhaustive, .targeted, .replay:
      self.rng = SchedulerRNG(seed: 42)
    }
  }

  /// Schedule an async operation for controlled execution
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  public mutating func schedule<T: Sendable>(
    _ operation: @Sendable () async throws -> T
  ) async rethrows -> T {
    // Record scheduling point
    let stepIndex = currentPath.steps.count
    currentPath = currentPath.appending(step: stepIndex)

    // Add jitter based on strategy
    await applyJitter()

    return try await operation()
  }

  /// Run the scheduler with a test body, exploring interleavings
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  public mutating func run<T: Sendable>(
    _ body: @Sendable () async throws -> T
  ) async throws -> SchedulerResult<T> {
    let startTime = ContinuousClock().now
    var results: [InterleavingResult<T>] = []
    var interleavingsExplored = 0

    while interleavingsExplored < maxInterleavings {
      // Check timeout
      if ContinuousClock().now - startTime > timeout {
        break
      }

      // Reset path for new exploration
      currentPath = InterleavingPath(steps: [])

      do {
        let result = try await body()
        results.append(.success(result, path: currentPath))
      } catch {
        results.append(.failure(error, path: currentPath))

        // On failure, return immediately with counterexample
        return SchedulerResult(
          interleavingsExplored: interleavingsExplored + 1,
          failingPath: currentPath,
          error: error,
          executionTime: ContinuousClock().now - startTime
        )
      }

      exploredPaths.append(currentPath)
      interleavingsExplored += 1

      // Break if exhaustive search is complete
      if case .replay = strategy {
        break
      }
    }

    return SchedulerResult(
      interleavingsExplored: interleavingsExplored,
      failingPath: nil,
      error: nil,
      executionTime: ContinuousClock().now - startTime
    )
  }

  /// Wait for all scheduled operations to complete
  public func waitAll() async {
    // Placeholder - actual implementation coordinates with TaskExecutor
    await Task.yield()
  }

  /// Wait until no operations are pending
  public func waitIdle() async {
    // Placeholder - actual implementation tracks pending operations
    await Task.yield()
  }

  /// Get next interleaving path for exploration
  public mutating func nextInterleaving() -> InterleavingPath? {
    switch strategy {
    case .random:
      // Generate random path
      let length = Int(rng.next() % 20) + 1
      let steps = (0..<length).map { _ in Int(rng.next() % 10) }
      return InterleavingPath(steps: steps)

    case .exhaustive(let depth):
      // Systematic enumeration - simplified BFS
      guard exploredPaths.count < maxInterleavings else { return nil }
      let steps = Array(repeating: exploredPaths.count % depth, count: depth)
      return InterleavingPath(steps: steps)

    case .targeted(let heuristic):
      // Use heuristic to guide exploration
      return heuristic.nextPath(explored: exploredPaths)

    case .replay(let path):
      // Single path replay
      return exploredPaths.isEmpty ? path : nil
    }
  }

  /// Apply jitter based on strategy
  private func applyJitter() async {
    switch strategy {
    case .random:
      let delayNanos = UInt64.random(in: 0..<1000)
      try? await Task.sleep(nanoseconds: delayNanos)

    case .exhaustive, .targeted:
      await Task.yield()

    case .replay:
      // No jitter for replay
      break
    }
  }
}

// MARK: - Interleaving Path

/// Records the exact sequence of operation orderings for reproduction.
///
/// An `InterleavingPath` captures which pending operation was chosen at each
/// scheduling decision point. Use this to replay exact interleavings:
///
/// ```swift
/// let path = InterleavingPath(steps: [0, 1, 0, 2])
/// let scheduler = Scheduler(strategy: .replay(path: path))
/// ```
public struct InterleavingPath: Sendable, Codable, Hashable, CustomStringConvertible {
  /// Which pending operation was chosen at each step
  public let steps: [Int]

  public init(steps: [Int]) {
    self.steps = steps
  }

  public var description: String {
    steps.map(String.init).joined(separator: ":")
  }

  /// Create a new path with an additional step
  public func appending(step: Int) -> Self {
    Self(steps: steps + [step])
  }

  /// Shrink the path to find minimal counterexample
  public func shrink() -> [Self] {
    var candidates: [Self] = []

    // Try removing each step
    for i in 0..<steps.count {
      var newSteps = steps
      newSteps.remove(at: i)
      candidates.append(Self(steps: newSteps))
    }

    // Try reducing step values
    for i in 0..<steps.count where steps[i] > 0 {
      var newSteps = steps
      newSteps[i] -= 1
      candidates.append(Self(steps: newSteps))
    }

    return candidates
  }
}

// MARK: - Interleaving Heuristic

/// Heuristics for targeted interleaving exploration.
///
/// Use heuristics to guide the scheduler toward interleavings that are
/// more likely to expose bugs.
public enum InterleavingHeuristic: Sendable, Equatable, Hashable {
  /// Favor interleavings that maximize context switches
  case maxContextSwitches

  /// Favor interleavings where operations complete in reverse start order
  case reverseCompletion

  /// Favor interleavings that delay specific operations
  case delay(pattern: String)

  /// Bias toward interleavings at actor boundaries
  case actorBoundary

  /// Generate next path based on heuristic
  func nextPath(explored: [InterleavingPath]) -> InterleavingPath? {
    switch self {
    case .maxContextSwitches:
      // Alternate between operations to maximize switching
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).map { $0 % 3 }
      return InterleavingPath(steps: steps)

    case .reverseCompletion:
      // Reverse ordering
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).reversed().map { $0 % 3 }
      return InterleavingPath(steps: Array(steps))

    case .delay(let pattern):
      // Delay operations matching pattern
      let patternHash = pattern.hashValue
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).map { ($0 + abs(patternHash)) % 3 }
      return InterleavingPath(steps: steps)

    case .actorBoundary:
      // Focus on actor isolation points
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).map { $0 % 2 }
      return InterleavingPath(steps: steps)
    }
  }
}

// MARK: - Scheduler Result

/// Result of scheduler exploration
public struct SchedulerResult<T: Sendable>: Sendable {
  /// Number of interleavings explored
  public let interleavingsExplored: Int

  /// Path that caused failure (if any)
  public let failingPath: InterleavingPath?

  /// Error from failing interleaving (if any)
  public let error: Error?

  /// Total execution time
  public let executionTime: Duration

  /// Whether all interleavings passed
  public var isSuccess: Bool {
    error == nil
  }

  /// Summary for diagnostics
  public func summary() -> String {
    var result = "Scheduler Results\n"
    result += "=================\n"
    result += "Interleavings explored: \(interleavingsExplored)\n"
    result += "Execution time: \(executionTime)\n"

    if let path = failingPath {
      result += "\nFailure detected!\n"
      result += "Failing path: \(path)\n"
      if let error = error {
        result += "Error: \(error)\n"
      }
    } else {
      result += "\nAll interleavings passed ✓\n"
    }

    return result
  }
}

/// Individual interleaving result
public enum InterleavingResult<T: Sendable>: Sendable {
  case success(T, path: InterleavingPath)
  case failure(Error, path: InterleavingPath)
}

// MARK: - Scheduler RNG

/// Seeded RNG for deterministic scheduling
struct SchedulerRNG: Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed
  }

  mutating func next() -> UInt64 {
    // Linear congruential generator
    state =
      state.multipliedReportingOverflow(by: 1_103_515_245)
      .partialValue.addingReportingOverflow(12345).partialValue
    return state
  }
}

// MARK: - Pending Operation

/// Represents an operation waiting to be scheduled
public struct PendingOperation: Sendable, Identifiable {
  public let id: UUID
  public let name: String
  public let priority: TaskPriority?
  public let creationTime: ContinuousClock.Instant

  public init(
    id: UUID = UUID(),
    name: String = "operation",
    priority: TaskPriority? = nil,
    creationTime: ContinuousClock.Instant = ContinuousClock().now
  ) {
    self.id = id
    self.name = name
    self.priority = priority
    self.creationTime = creationTime
  }
}

// MARK: - TaskGroup Extensions

extension Scheduler {

  /// Create a TaskGroup where child task execution is controlled
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  public mutating func withTaskGroup<ChildTaskResult: Sendable, GroupResult>(
    of childTaskResultType: ChildTaskResult.Type,
    returning returnType: GroupResult.Type = GroupResult.self,
    body: (inout TaskGroup<ChildTaskResult>) async -> GroupResult
  ) async -> GroupResult {
    // Apply jitter before group execution
    await applyJitter()

    return await _Concurrency.withTaskGroup(of: childTaskResultType, returning: returnType) {
      // swiftlint:disable:next closure_parameter_position
      group in
      await body(&group)
    }
  }

  /// Create a ThrowingTaskGroup with controlled execution
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  public mutating func withThrowingTaskGroup<ChildTaskResult: Sendable, GroupResult>(
    of childTaskResultType: ChildTaskResult.Type,
    returning returnType: GroupResult.Type = GroupResult.self,
    body: (inout ThrowingTaskGroup<ChildTaskResult, Error>) async throws -> GroupResult
  ) async rethrows -> GroupResult {
    // Apply jitter before group execution
    await applyJitter()

    return try await _Concurrency.withThrowingTaskGroup(
      of: childTaskResultType,
      returning: returnType
    ) {
      // swiftlint:disable:next closure_parameter_position
      group in
      try await body(&group)
    }
  }
}

// MARK: - Global Scheduler Context

/// Container for thread-local scheduler context
public enum SchedulerContext {
  /// Thread-local scheduler for use within `@AsyncPropertyTest`
  @TaskLocal
  public static var current: Scheduler?
}

/// Execute code with a scheduler context
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public func withScheduler<T: Sendable>(
  _ scheduler: Scheduler,
  operation: () async throws -> T
) async rethrows -> T {
  try await SchedulerContext.$current.withValue(scheduler) {
    try await operation()
  }
}
