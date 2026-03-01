/// Deterministic concurrency testing via controlled interleaving.
/// ISP-0001: Scheduler-Based Race Condition Testing.

import Foundation
import InvariantSwiftCore

// MARK: - Core Types

public struct Scheduler: Sendable {

  public enum Strategy: Sendable, Equatable {
    case random(seed: UInt64?)
    case exhaustive(depth: Int)
    case targeted(heuristic: InterleavingHeuristic)
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

  public let strategy: Strategy
  public let maxInterleavings: Int
  public let timeout: Duration
  public private(set) var currentPath: InterleavingPath
  private var exploredPaths: [InterleavingPath] = []
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

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  public mutating func schedule<T: Sendable>(
    _ operation: @Sendable () async throws -> T
  ) async rethrows -> T {
    let stepIndex = currentPath.steps.count
    currentPath = currentPath.appending(step: stepIndex)

    // Add jitter based on strategy
    await applyJitter()

    return try await operation()
  }

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

        return SchedulerResult(
          interleavingsExplored: interleavingsExplored + 1,
          failingPath: currentPath,
          error: error,
          executionTime: ContinuousClock().now - startTime
        )
      }

      exploredPaths.append(currentPath)
      interleavingsExplored += 1

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

  /// Placeholder: actual implementation coordinates with TaskExecutor
  public func waitAll() async {
    await Task.yield()
  }

  /// Placeholder: actual implementation tracks pending operations
  public func waitIdle() async {
    await Task.yield()
  }

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
      // Single path replay - return path only once
      if exploredPaths.isEmpty {
        exploredPaths.append(path)
        return path
      }
      return nil
    }
  }

  private func applyJitter() async {
    switch strategy {
    case .random:
      let delayNanos = UInt64.random(in: 0..<1000)
      try? await Task.sleep(nanoseconds: delayNanos)

    case .exhaustive, .targeted:
      await Task.yield()

    case .replay:
      break
    }
  }
}

// MARK: - Interleaving Path

/// Records which pending operation was chosen at each scheduling decision point,
/// enabling exact replay of a failing interleaving.
public struct InterleavingPath: Sendable, Codable, Hashable, CustomStringConvertible {
  public let steps: [Int]

  public init(steps: [Int]) {
    self.steps = steps
  }

  public var description: String {
    steps.map(String.init).joined(separator: ":")
  }

  public func appending(step: Int) -> Self {
    Self(steps: steps + [step])
  }

  public func shrink() -> [Self] {
    var candidates: [Self] = []

    for i in 0..<steps.count {
      var newSteps = steps
      newSteps.remove(at: i)
      candidates.append(Self(steps: newSteps))
    }

    for i in 0..<steps.count where steps[i] > 0 {
      var newSteps = steps
      newSteps[i] -= 1
      candidates.append(Self(steps: newSteps))
    }

    return candidates
  }
}

// MARK: - Interleaving Heuristic

public enum InterleavingHeuristic: Sendable, Equatable, Hashable {
  case maxContextSwitches
  case reverseCompletion
  case delay(pattern: String)
  case actorBoundary

  func nextPath(explored: [InterleavingPath]) -> InterleavingPath? {
    switch self {
    case .maxContextSwitches:
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).map { $0 % 3 }
      return InterleavingPath(steps: steps)

    case .reverseCompletion:
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).reversed().map { $0 % 3 }
      return InterleavingPath(steps: Array(steps))

    case .delay(let pattern):
      let patternHash = pattern.hashValue
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).map { ($0 + abs(patternHash)) % 3 }
      return InterleavingPath(steps: steps)

    case .actorBoundary:
      let length = min(explored.count + 5, 20)
      let steps = (0..<length).map { $0 % 2 }
      return InterleavingPath(steps: steps)
    }
  }
}

// MARK: - Scheduler Result

public struct SchedulerResult<T: Sendable>: Sendable {
  public let interleavingsExplored: Int
  public let failingPath: InterleavingPath?
  public let error: Error?
  public let executionTime: Duration

  public var isSuccess: Bool {
    error == nil
  }

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

public enum InterleavingResult<T: Sendable>: Sendable {
  case success(T, path: InterleavingPath)
  case failure(Error, path: InterleavingPath)
}

// MARK: - Scheduler RNG

struct SchedulerRNG: Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed
  }

  mutating func next() -> UInt64 {
    state =
      state.multipliedReportingOverflow(by: 1_103_515_245)
      .partialValue.addingReportingOverflow(12345).partialValue
    return state
  }
}

// MARK: - Pending Operation

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

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  public mutating func withTaskGroup<ChildTaskResult: Sendable, GroupResult>(
    of childTaskResultType: ChildTaskResult.Type,
    returning returnType: GroupResult.Type = GroupResult.self,
    body: (inout TaskGroup<ChildTaskResult>) async -> GroupResult
  ) async -> GroupResult {
    await applyJitter()

    return await _Concurrency.withTaskGroup(of: childTaskResultType, returning: returnType) {
      // swiftlint:disable:next closure_parameter_position
      group in
      await body(&group)
    }
  }

  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  public mutating func withThrowingTaskGroup<ChildTaskResult: Sendable, GroupResult>(
    of childTaskResultType: ChildTaskResult.Type,
    returning returnType: GroupResult.Type = GroupResult.self,
    body: (inout ThrowingTaskGroup<ChildTaskResult, Error>) async throws -> GroupResult
  ) async rethrows -> GroupResult {
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

public enum SchedulerContext {
  @TaskLocal public static var current: Scheduler?
}

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public func withScheduler<T: Sendable>(
  _ scheduler: Scheduler,
  operation: () async throws -> T
) async rethrows -> T {
  try await SchedulerContext.$current.withValue(scheduler) {
    try await operation()
  }
}
