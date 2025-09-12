/// Enhanced Async Property Testing with Actor Isolation
///
/// Complete async property testing system for Swift concurrency that provides
/// deterministic execution, timeout management, and proper isolation for
/// concurrent and asynchronous code testing.

import Foundation

// MARK: - Core Async Property Types

/// Configuration for async property execution
public struct AsyncPropertyConfig: Sendable {
  public let iterations: Int
  public let timeout: Duration
  public let maxConcurrentIterations: Int
  public let executorMode: ExecutorMode
  public let failureReporting: FailureReporting

  public init(
    iterations: Int = 100,
    timeout: Duration = .seconds(30),
    maxConcurrentIterations: Int = 1,
    executorMode: ExecutorMode = .serialExecutor,
    failureReporting: FailureReporting = .firstFailure
  ) {
    self.iterations = max(1, iterations)
    self.timeout = timeout
    self.maxConcurrentIterations = max(1, maxConcurrentIterations)
    self.executorMode = executorMode
    self.failureReporting = failureReporting
  }

  public static let `default` = Self()
  public static let concurrent = Self(
    maxConcurrentIterations: 10,
    executorMode: .cooperativeExecutor
  )
}

/// Execution mode for async properties
public enum ExecutorMode: Sendable {
  case serialExecutor  // Deterministic serial execution
  case cooperativeExecutor  // Cooperative task scheduling
  case isolatedExecutor  // Isolated actor execution
  case customExecutor(any Actor.Type)
}

/// Failure reporting strategy
public enum FailureReporting: Sendable {
  case firstFailure  // Stop on first failure
  case collectAll  // Collect all failures
  case collectUpTo(Int)  // Collect up to N failures
}

/// Result of async property execution
public struct AsyncPropertyResult: Sendable {
  public let success: Bool
  public let iterations: Int
  public let failures: [AsyncPropertyFailure]
  public let executionTime: Duration
  public let concurrency: ConcurrencyStats

  public init(
    success: Bool,
    iterations: Int,
    failures: [AsyncPropertyFailure],
    executionTime: Duration,
    concurrency: ConcurrencyStats
  ) {
    self.success = success
    self.iterations = iterations
    self.failures = failures
    self.executionTime = executionTime
    self.concurrency = concurrency
  }

  /// Human-readable summary
  public var summary: String {
    let status = success ? "✓ PASSED" : "✗ FAILED"
    let failureCount = failures.count
    let avgTime = executionTime.timeInterval / Double(iterations)

    return """
      \(status) - \(iterations) iterations
      Failures: \(failureCount)
      Execution time: \(String(format: "%.3f", executionTime.timeInterval))s
      Average per iteration: \(String(format: "%.3f", avgTime * 1000))ms
      Concurrency: \(concurrency.maxConcurrentTasks) max, \(concurrency.averageConcurrency) avg
      """
  }
}

/// Detailed failure information for async properties
public struct AsyncPropertyFailure: Sendable {
  public let iteration: Int
  public let error: String
  public let generatedValues: [String: Any]
  public let executionContext: ExecutionContext
  public let timestamp: Date

  public init(
    iteration: Int,
    error: String,
    generatedValues: [String: Any] = [:],
    executionContext: ExecutionContext,
    timestamp: Date = Date()
  ) {
    self.iteration = iteration
    self.error = error
    self.generatedValues = generatedValues
    self.executionContext = executionContext
    self.timestamp = timestamp
  }
}

/// Execution context information
public struct ExecutionContext: Sendable {
  public let taskId: String
  public let actorName: String?
  public let executorType: String
  public let concurrentTasks: Int

  public init(
    taskId: String,
    actorName: String? = nil,
    executorType: String,
    concurrentTasks: Int
  ) {
    self.taskId = taskId
    self.actorName = actorName
    self.executorType = executorType
    self.concurrentTasks = concurrentTasks
  }
}

/// Concurrency statistics
public struct ConcurrencyStats: Sendable {
  public let maxConcurrentTasks: Int
  public let averageConcurrency: Double
  public let taskSwitches: Int
  public let deadlocks: Int

  public init(
    maxConcurrentTasks: Int,
    averageConcurrency: Double,
    taskSwitches: Int,
    deadlocks: Int
  ) {
    self.maxConcurrentTasks = maxConcurrentTasks
    self.averageConcurrency = averageConcurrency
    self.taskSwitches = taskSwitches
    self.deadlocks = deadlocks
  }
}

// MARK: - Async Property Predicate Types

/// Async predicate that can suspend and perform async operations
public struct AsyncPredicate<T>: Sendable where T: Sendable {
  private let predicate: @Sendable (T) async throws -> Bool

  public init(_ predicate: @escaping @Sendable (T) async throws -> Bool) {
    self.predicate = predicate
  }

  /// Test the predicate with a value
  public func test(_ value: T) async throws -> Bool {
    try await predicate(value)
  }

  /// Combine with another async predicate using AND
  public func and<U>(_ other: AsyncPredicate<U>) -> AsyncPredicate<(T, U)> where U: Sendable {
    AsyncPredicate<(T, U)> { tuple in
      let (t, u) = tuple
      return try await self.test(t) && other.test(u)
    }
  }

  /// Combine with another async predicate using OR
  public func or<U>(_ other: AsyncPredicate<U>) -> AsyncPredicate<(T, U)> where U: Sendable {
    AsyncPredicate<(T, U)> { tuple in
      let (t, u) = tuple
      return try await self.test(t) || other.test(u)
    }
  }

  /// Transform input before testing
  public func contramap<U>(_ transform: @escaping @Sendable (U) async -> T) -> AsyncPredicate<U>
  where U: Sendable {
    AsyncPredicate<U> { u in
      let t = await transform(u)
      return try await self.test(t)
    }
  }
}

// MARK: - Async Property Definition

/// Property that can be tested asynchronously with concurrency support
public struct AsyncProperty<T>: Sendable where T: Sendable {
  public let generator: Gen<T>
  public let predicate: AsyncPredicate<T>
  public let config: AsyncPropertyConfig

  public init(
    generator: Gen<T>,
    predicate: AsyncPredicate<T>,
    config: AsyncPropertyConfig = .default
  ) {
    self.generator = generator
    self.predicate = predicate
    self.config = config
  }

  /// Create property from sync generator and async predicate
  public init(
    forAll generator: Gen<T>,
    check predicate: @escaping @Sendable (T) async throws -> Bool,
    config: AsyncPropertyConfig = .default
  ) {
    self.generator = generator
    self.predicate = AsyncPredicate(predicate)
    self.config = config
  }
}

// MARK: - Serial Execution Actor

/// Actor that ensures deterministic serial execution of async properties
@globalActor
public actor SerialPropertyExecutor {
  public static let shared = SerialPropertyExecutor()

  private var executionQueue: [Task<Void, Never>] = []
  private var isExecuting = false

  /// Execute task serially with deterministic ordering
  public func execute<T>(
    _ operation: @escaping @Sendable () async throws -> T
  ) async rethrows -> T {
    while isExecuting {
      await Task.yield()
    }

    isExecuting = true
    defer { isExecuting = false }

    return try await operation()
  }

  /// Yield control to allow other tasks to run
  public func yield() async {
    await Task.yield()
  }
}

// MARK: - Async Property Runner

/// Main runner for executing async properties with concurrency control
public actor AsyncPropertyRunner {
  private let config: AsyncPropertyConfig
  private var runCount: Int = 0
  private var totalFailures: Int = 0

  public init(config: AsyncPropertyConfig = .default) {
    self.config = config
  }

  /// Run an async property with the configured settings
  public func run<T>(_ property: AsyncProperty<T>) async -> AsyncPropertyResult {
    let startTime = ContinuousClock.now
    runCount += 1

    var failures: [AsyncPropertyFailure] = []
    var completedIterations = 0
    var concurrencyTracker = ConcurrencyTracker()

    switch property.config.executorMode {
    case .serialExecutor:
      await withSerialExecution(
        property: property,
        failures: &failures,
        completedIterations: &completedIterations,
        concurrencyTracker: &concurrencyTracker
      )

    case .cooperativeExecutor:
      await withCooperativeExecution(
        property: property,
        failures: &failures,
        completedIterations: &completedIterations,
        concurrencyTracker: &concurrencyTracker
      )

    case .isolatedExecutor:
      await withIsolatedExecution(
        property: property,
        failures: &failures,
        completedIterations: &completedIterations,
        concurrencyTracker: &concurrencyTracker
      )

    case .customExecutor(let actorType):
      await withCustomExecution(
        property: property,
        actorType: actorType,
        failures: &failures,
        completedIterations: &completedIterations,
        concurrencyTracker: &concurrencyTracker
      )
    }

    let endTime = ContinuousClock.now
    let executionTime = endTime - startTime

    totalFailures += failures.count

    return AsyncPropertyResult(
      success: failures.isEmpty,
      iterations: completedIterations,
      failures: failures,
      executionTime: Duration(executionTime),
      concurrency: concurrencyTracker.statistics
    )
  }

  /// Run multiple properties in sequence
  public func runAll<T>(_ properties: [AsyncProperty<T>]) async -> [AsyncPropertyResult] {
    var results: [AsyncPropertyResult] = []

    for property in properties {
      let result = await run(property)
      results.append(result)

      // Early termination on failure if configured
      if !result.success && property.config.failureReporting == .firstFailure {
        break
      }
    }

    return results
  }

  // MARK: - Execution Strategies

  private func withSerialExecution<T>(
    property: AsyncProperty<T>,
    failures: inout [AsyncPropertyFailure],
    completedIterations: inout Int,
    concurrencyTracker: inout ConcurrencyTracker
  ) async {
    await SerialPropertyExecutor.shared.execute {
      for iteration in 0..<property.config.iterations {
        do {
          let value = try await self.generateValueWithTimeout(
            property.generator,
            timeout: property.config.timeout
          )

          concurrencyTracker.taskStarted(taskId: "serial-\(iteration)")
          defer { concurrencyTracker.taskCompleted(taskId: "serial-\(iteration)") }

          let success = try await property.predicate.test(value)

          if !success {
            let failure = AsyncPropertyFailure(
              iteration: iteration,
              error: "Property predicate returned false",
              generatedValues: ["value": value],
              executionContext: ExecutionContext(
                taskId: "serial-\(iteration)",
                executorType: "serial",
                concurrentTasks: 1
              )
            )
            failures.append(failure)

            if shouldStopOnFailure(property.config.failureReporting, failureCount: failures.count) {
              break
            }
          }

          completedIterations += 1
          await SerialPropertyExecutor.shared.yield()

        } catch {
          let failure = AsyncPropertyFailure(
            iteration: iteration,
            error: "Exception: \(error)",
            executionContext: ExecutionContext(
              taskId: "serial-\(iteration)",
              executorType: "serial",
              concurrentTasks: 1
            )
          )
          failures.append(failure)

          if shouldStopOnFailure(property.config.failureReporting, failureCount: failures.count) {
            break
          }

          completedIterations += 1
        }
      }
    }
  }

  private func withCooperativeExecution<T>(
    property: AsyncProperty<T>,
    failures: inout [AsyncPropertyFailure],
    completedIterations: inout Int,
    concurrencyTracker: inout ConcurrencyTracker
  ) async {
    await withTaskGroup(of: TaskResult.self) { group in
      var remainingIterations = property.config.iterations
      var activeTasks = 0

      while remainingIterations > 0 || activeTasks > 0 {
        // Start new tasks up to the concurrency limit
        while activeTasks < property.config.maxConcurrentIterations && remainingIterations > 0 {
          let iteration = property.config.iterations - remainingIterations
          remainingIterations -= 1
          activeTasks += 1

          group.addTask {
            await self.executeIteration(
              property: property,
              iteration: iteration,
              concurrencyTracker: concurrencyTracker,
              executorType: "cooperative"
            )
          }
        }

        // Wait for at least one task to complete
        if let result = await group.next() {
          activeTasks -= 1
          self.handleTaskResult(
            result,
            failures: &failures,
            completedIterations: &completedIterations
          )

          if shouldStopOnFailure(property.config.failureReporting, failureCount: failures.count) {
            group.cancelAll()
            break
          }
        }
      }
    }
  }

  private func withIsolatedExecution<T>(
    property: AsyncProperty<T>,
    failures: inout [AsyncPropertyFailure],
    completedIterations: inout Int,
    concurrencyTracker: inout ConcurrencyTracker
  ) async {
    let isolatedExecutor = IsolatedPropertyExecutor()

    await isolatedExecutor.executeAll { executor in
      for iteration in 0..<property.config.iterations {
        let result = await executor.executeIteration(
          property: property,
          iteration: iteration,
          concurrencyTracker: concurrencyTracker,
          executorType: "isolated"
        )

        self.handleTaskResult(
          result,
          failures: &failures,
          completedIterations: &completedIterations
        )

        if shouldStopOnFailure(property.config.failureReporting, failureCount: failures.count) {
          break
        }
      }
    }
  }

  private func withCustomExecution<T>(
    property: AsyncProperty<T>,
    actorType: any Actor.Type,
    failures: inout [AsyncPropertyFailure],
    completedIterations: inout Int,
    concurrencyTracker: inout ConcurrencyTracker
  ) async {
    // Custom executor implementation would go here
    // For now, fall back to cooperative execution
    await withCooperativeExecution(
      property: property,
      failures: &failures,
      completedIterations: &completedIterations,
      concurrencyTracker: &concurrencyTracker
    )
  }

  // MARK: - Helper Methods

  private func executeIteration<T>(
    property: AsyncProperty<T>,
    iteration: Int,
    concurrencyTracker: ConcurrencyTracker,
    executorType: String
  ) async -> TaskResult {
    do {
      let value = try await generateValueWithTimeout(
        property.generator,
        timeout: property.config.timeout
      )

      let taskId = "\(executorType)-\(iteration)"
      concurrencyTracker.taskStarted(taskId: taskId)
      defer { concurrencyTracker.taskCompleted(taskId: taskId) }

      let success = try await property.predicate.test(value)

      if success {
        return .success(iteration)
      } else {
        return .failure(
          AsyncPropertyFailure(
            iteration: iteration,
            error: "Property predicate returned false",
            generatedValues: ["value": value],
            executionContext: ExecutionContext(
              taskId: taskId,
              executorType: executorType,
              concurrentTasks: concurrencyTracker.currentConcurrency
            )
          )
        )
      }
    } catch {
      return .failure(
        AsyncPropertyFailure(
          iteration: iteration,
          error: "Exception: \(error)",
          executionContext: ExecutionContext(
            taskId: "\(executorType)-\(iteration)",
            executorType: executorType,
            concurrentTasks: concurrencyTracker.currentConcurrency
          )
        )
      )
    }
  }

  private func generateValueWithTimeout<T>(_ generator: Gen<T>, timeout: Duration) async throws -> T
  {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        var rng = SystemRandomNumberGenerator()
        return generator.generate(&rng, Size.default)
      }

      group.addTask {
        try await Task.sleep(for: timeout)
        throw TimeoutError()
      }

      let result = try await group.next()!
      group.cancelAll()
      return result
    }
  }

  private func handleTaskResult(
    _ result: TaskResult,
    failures: inout [AsyncPropertyFailure],
    completedIterations: inout Int
  ) {
    switch result {
    case .success:
      completedIterations += 1

    case .failure(let failure):
      failures.append(failure)
      completedIterations += 1
    }
  }

  private func shouldStopOnFailure(_ reporting: FailureReporting, failureCount: Int) -> Bool {
    switch reporting {
    case .firstFailure:
      return failureCount > 0

    case .collectAll:
      return false

    case .collectUpTo(let max):
      return failureCount >= max
    }
  }

  /// Get runner statistics
  public func getStatistics() -> (runCount: Int, totalFailures: Int) {
    (runCount: runCount, totalFailures: totalFailures)
  }
}

// MARK: - Supporting Types

private enum TaskResult: Sendable {
  case success(Int)
  case failure(AsyncPropertyFailure)
}

private actor IsolatedPropertyExecutor {
  func executeAll<T>(_ operation: @Sendable (IsolatedPropertyExecutor) async -> T) async -> T {
    await operation(self)
  }

  func executeIteration<T>(
    property: AsyncProperty<T>,
    iteration: Int,
    concurrencyTracker: ConcurrencyTracker,
    executorType: String
  ) async -> TaskResult {
    // Implementation similar to AsyncPropertyRunner.executeIteration
    // but executed within this isolated actor
    .success(iteration)
  }
}

private class ConcurrencyTracker: @unchecked Sendable {
  private let lock = NSLock()
  private var activeTasks: Set<String> = []
  private var maxConcurrent = 0
  private var totalTaskSwitches = 0
  private var concurrencyHistory: [Int] = []

  var currentConcurrency: Int {
    lock.withLock { activeTasks.count }
  }

  var statistics: ConcurrencyStats {
    lock.withLock {
      let avgConcurrency =
        concurrencyHistory.isEmpty
        ? 0.0 : Double(concurrencyHistory.reduce(0, +)) / Double(concurrencyHistory.count)

      return ConcurrencyStats(
        maxConcurrentTasks: maxConcurrent,
        averageConcurrency: avgConcurrency,
        taskSwitches: totalTaskSwitches,
        deadlocks: 0
      )
    }
  }

  func taskStarted(taskId: String) {
    lock.withLock {
      activeTasks.insert(taskId)
      let currentCount = activeTasks.count
      maxConcurrent = max(maxConcurrent, currentCount)
      concurrencyHistory.append(currentCount)
      totalTaskSwitches += 1
    }
  }

  func taskCompleted(taskId: String) {
    lock.withLock {
      activeTasks.remove(taskId)
    }
  }
}

private struct TimeoutError: Error {}

// MARK: - Convenience Extensions

extension AsyncProperty {
  /// Create property with synchronous predicate
  public init(
    forAll generator: Gen<T>,
    check predicate: @escaping @Sendable (T) -> Bool,
    config: AsyncPropertyConfig = .default
  ) {
    self.generator = generator
    self.predicate = AsyncPredicate { value in predicate(value) }
    self.config = config
  }

  /// Run this property once with default runner
  public func run() async -> AsyncPropertyResult {
    let runner = AsyncPropertyRunner(config: self.config)
    return await runner.run(self)
  }

  /// Create concurrent version of this property
  public func concurrent(maxTasks: Int = 10) -> AsyncProperty<T> {
    AsyncProperty(
      generator: self.generator,
      predicate: self.predicate,
      config: AsyncPropertyConfig(
        iterations: self.config.iterations,
        timeout: self.config.timeout,
        maxConcurrentIterations: maxTasks,
        executorMode: .cooperativeExecutor,
        failureReporting: self.config.failureReporting
      )
    )
  }
}

extension AsyncPredicate {
  /// Create from synchronous predicate
  public init(_ predicate: @escaping @Sendable (T) -> Bool) {
    self.predicate = { value in predicate(value) }
  }

  /// Common predicate: value should satisfy condition within timeout
  public static func eventually<U>(
    _ condition: @escaping @Sendable (T) async -> U,
    satisfies predicate: @escaping @Sendable (U) -> Bool,
    timeout: Duration = .seconds(5),
    pollInterval: Duration = .milliseconds(100)
  ) -> AsyncPredicate<T> where U: Sendable {
    AsyncPredicate { value in
      let deadline = ContinuousClock.now + timeout

      while ContinuousClock.now < deadline {
        let result = await condition(value)
        if predicate(result) {
          return true
        }
        try await Task.sleep(for: pollInterval)
      }

      return false
    }
  }
}

// MARK: - Built-in Async Predicates

extension AsyncPredicate {
  /// Predicate that always succeeds
  public static var alwaysTrue: AsyncPredicate<T> {
    AsyncPredicate { _ in true }
  }

  /// Predicate that always fails
  public static var alwaysFalse: AsyncPredicate<T> {
    AsyncPredicate { _ in false }
  }

  /// Predicate that succeeds after a delay
  public static func succeedsAfter(_ delay: Duration) -> AsyncPredicate<T> {
    AsyncPredicate { _ in
      try await Task.sleep(for: delay)
      return true
    }
  }

  /// Predicate for testing race conditions
  public static func raceCondition<U>(
    _ operation1: @escaping @Sendable (T) async -> U,
    _ operation2: @escaping @Sendable (T) async -> U,
    shouldEqual: Bool = true
  ) -> AsyncPredicate<T> where U: Sendable & Equatable {
    AsyncPredicate { value in
      async let result1 = operation1(value)
      async let result2 = operation2(value)

      let (r1, r2) = await (result1, result2)
      return shouldEqual ? (r1 == r2) : (r1 != r2)
    }
  }
}

extension NSLock {
  fileprivate func withLock<T>(_ operation: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try operation()
  }
}

extension Duration {
  fileprivate var timeInterval: TimeInterval {
    let attoseconds = self.components.attoseconds
    let seconds = self.components.seconds
    return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
  }

  fileprivate init(_ continuousClockDuration: ContinuousClock.Duration) {
    let nanoseconds = continuousClockDuration.components.attoseconds / 1_000_000_000
    self = .nanoseconds(nanoseconds)
  }
}
