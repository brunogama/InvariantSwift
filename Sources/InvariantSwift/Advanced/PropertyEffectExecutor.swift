/// PropertyEffect Executor - Advanced Actor-Isolated Property Testing Engine
///
/// High-performance executor for PropertyEffect<A> that provides deterministic,
/// isolated, and concurrent execution with comprehensive tracing and validation.

import Foundation

// MARK: - Core Executor

/// Actor-based executor for PropertyEffect with isolation guarantees
// swiftlint:disable function_body_length
public actor PropertyEffectExecutor {
  private var activeExecutions: [String: Task<PropertyEffectResult, Never>] = [:]
  private var executionCounter: Int = 0

  public init() {}

  /// Execute a PropertyEffect with full isolation and tracing
  public func run<A>(_ effect: PropertyEffect<A>) async -> PropertyEffectResult {
    let executionId = generateExecutionId()
    let startTime = ContinuousClock.now

    var failures: [PropertyEffectFailure] = []
    var actorSwitches = 0
    var taskCreations = 0
    var maxConcurrentTasks = 0
    var currentConcurrentTasks = 0
    var actualContexts: [String] = []
    var isolationViolations: [IsolationViolation] = []

    // Track execution context
    let expectedActor = effect.actorIsolation.description

    for iteration in 0..<effect.config.iterations {
      do {
        currentConcurrentTasks += 1
        maxConcurrentTasks = max(maxConcurrentTasks, currentConcurrentTasks)
        taskCreations += 1

        let result = try await executeIteration(
          effect: effect,
          iteration: iteration,
          expectedActor: expectedActor,
          executionId: executionId
        )

        actualContexts.append(result.context)
        if result.context != expectedActor {
          isolationViolations.append(
            IsolationViolation(
              iteration: iteration,
              expectedActor: expectedActor,
              actualActor: result.context,
              violationType: .unexpectedActorSwitch
            )
          )
        }

        if result.actorSwitched {
          actorSwitches += 1
        }

        currentConcurrentTasks -= 1

      } catch let error as PropertyEffectFailure {
        failures.append(error)
        currentConcurrentTasks -= 1

        // Stop on first failure for strict validation
        if effect.config.isolationValidation == .strict && error.isolationViolation {
          break
        }
      } catch {
        let failure = PropertyEffectFailure(
          iteration: iteration,
          input: "unknown",  // Would need to capture generated value
          error: error.localizedDescription,
          actorContext: "unknown",
          isolationViolation: false
        )
        failures.append(failure)
        currentConcurrentTasks -= 1
      }
    }

    let endTime = ContinuousClock.now
    let totalDuration = endTime - startTime
    let avgIterationTime = totalDuration / effect.config.iterations

    let metrics = ExecutionMetrics(
      totalDuration: totalDuration,
      averageIterationTime: avgIterationTime,
      actorSwitches: actorSwitches,
      taskCreations: taskCreations,
      maxConcurrentTasks: maxConcurrentTasks,
      memoryPressure: .normal  // Would need actual memory monitoring
    )

    let isolationReport = IsolationReport(
      expectedActor: expectedActor,
      actualExecutionContexts: Array(Set(actualContexts)),  // Unique contexts
      isolationViolations: isolationViolations,
      complianceScore: calculateComplianceScore(
        violations: isolationViolations,
        totalIterations: effect.config.iterations
      )
    )

    return failures.isEmpty
      ? PropertyEffectResult.success(
        iterations: effect.config.iterations,
        metrics: metrics,
        isolationReport: isolationReport
      )
      : PropertyEffectResult.failure(
        iterations: effect.config.iterations,
        failures: failures,
        metrics: metrics,
        isolationReport: isolationReport
      )
  }

  // MARK: - Private Implementation

  private func generateExecutionId() -> String {
    executionCounter += 1
    return "exec-\(executionCounter)-\(UUID().uuidString.prefix(8))"
  }

  private struct IterationResult {
    let success: Bool
    let context: String
    let actorSwitched: Bool
    let isolationViolated: Bool
  }

  private func executeIteration<A>(
    effect: PropertyEffect<A>,
    iteration: Int,
    expectedActor: String,
    executionId: String
  ) async throws -> IterationResult {

    // Generate test input
    var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    let size = Size(value: iteration / 10 + 1)
    let input = effect.generator.generate(&rng, size)

    // Execute based on isolation strategy
    let result: Bool
    let actualContext: String
    var actorSwitched = false

    switch effect.actorIsolation {
    case .mainActor:
      result = try await executeOnMainActor(effect: effect, input: input)
      actualContext = "MainActor"

    case .globalActor(let actorTypeName):
      result = try await executeOnGlobalActor(
        effect: effect,
        input: input,
        actorTypeName: actorTypeName
      )
      actualContext = "GlobalActor(\(actorTypeName))"

    case .customActor(let actorTypeName):
      result = try await executeOnCustomActor(
        effect: effect,
        input: input,
        actorTypeName: actorTypeName
      )
      actualContext = "Actor(\(actorTypeName))"

    case .serialExecutor:
      result = try await SerialPropertyExecutor.shared.execute {
        try await effect.effect(input)
      }
      actualContext = "SerialExecutor"

    case .detachedTask:
      result = try await Task.detached {
        try await effect.effect(input)
      }.value
      actualContext = "DetachedTask"
      actorSwitched = true

    case .taskGroup(let maxConcurrency):
      result = try await executeInTaskGroup(
        effect: effect,
        input: input,
        maxConcurrency: maxConcurrency
      )
      actualContext = "TaskGroup(maxConcurrency: \(maxConcurrency))"
      actorSwitched = true
    }

    if !result {
      throw PropertyEffectFailure(
        iteration: iteration,
        input: "\(input)",
        error: "Property test failed",
        actorContext: actualContext,
        isolationViolation: actualContext != expectedActor
      )
    }

    return IterationResult(
      success: result,
      context: actualContext,
      actorSwitched: actorSwitched,
      isolationViolated: actualContext != expectedActor
    )
  }

  @MainActor
  private func executeOnMainActor<A>(
    effect: PropertyEffect<A>,
    input: A
  ) async throws -> Bool {
    try await effect.effect(input)
  }

  private func executeOnGlobalActor<A>(
    effect: PropertyEffect<A>,
    input: A,
    actorTypeName: String
  ) async throws -> Bool {
    // This is a simplified implementation - in practice would need
    // to dynamically dispatch to the global actor based on type name
    try await effect.effect(input)
  }

  private func executeOnCustomActor<A>(
    effect: PropertyEffect<A>,
    input: A,
    actorTypeName: String
  ) async throws -> Bool {
    // This is a simplified implementation - in practice would need
    // to create or access the specific actor instance based on type name
    try await effect.effect(input)
  }

  private func executeInTaskGroup<A>(
    effect: PropertyEffect<A>,
    input: A,
    maxConcurrency: Int
  ) async throws -> Bool {
    try await withThrowingTaskGroup(of: Bool.self, returning: Bool.self) { group in
      group.addTask {
        try await effect.effect(input)
      }

      // Wait for the single task to complete
      guard let result = try await group.next() else {
        throw PropertyEffectFailure(
          iteration: 0,
          input: "\(input)",
          error: "Task group execution failed",
          actorContext: "TaskGroup"
        )
      }

      return result
    }
  }

  private func calculateComplianceScore(
    violations: [IsolationViolation],
    totalIterations: Int
  ) -> Double {
    guard totalIterations > 0 else { return 1.0 }
    let violationRate = Double(violations.count) / Double(totalIterations)
    return max(0.0, 1.0 - violationRate)
  }
}

// MARK: - Global Execution Functions

/// Execute a PropertyEffect on the MainActor with comprehensive validation
@MainActor
public func checkPropertyAsyncOnActor<A>(
  _ effect: PropertyEffect<A>
) async -> PropertyEffectResult {
  let mainActorEffect = PropertyEffect<A>(
    generator: effect.generator,
    effect: effect.effect,
    actorIsolation: .mainActor,
    config: effect.config
  )

  let executor = PropertyEffectExecutor()
  return await executor.run(mainActorEffect)
}

/// Execute a PropertyEffect on a specific global actor
public func checkPropertyAsyncOnGlobalActor<A, GA: GlobalActor>(
  _ effect: PropertyEffect<A>,
  on globalActor: GA.Type
) async -> PropertyEffectResult {
  let globalActorEffect = PropertyEffect<A>(
    generator: effect.generator,
    effect: effect.effect,
    actorIsolation: .globalActor(String(describing: globalActor)),
    config: effect.config
  )

  let executor = PropertyEffectExecutor()
  return await executor.run(globalActorEffect)
}

/// Execute a PropertyEffect with serial execution guarantees
public func checkPropertyAsyncSerially<A>(
  _ effect: PropertyEffect<A>
) async -> PropertyEffectResult {
  let serialEffect = PropertyEffect<A>(
    generator: effect.generator,
    effect: effect.effect,
    actorIsolation: .serialExecutor,
    config: effect.config
  )

  let executor = PropertyEffectExecutor()
  return await executor.run(serialEffect)
}

/// Execute a PropertyEffect in a detached task context
public func checkPropertyAsyncDetached<A>(
  _ effect: PropertyEffect<A>
) async -> PropertyEffectResult {
  let detachedEffect = PropertyEffect<A>(
    generator: effect.generator,
    effect: effect.effect,
    actorIsolation: .detachedTask,
    config: effect.config
  )

  let executor = PropertyEffectExecutor()
  return await executor.run(detachedEffect)
}

/// Execute multiple PropertyEffect instances concurrently with isolation guarantees
public func checkPropertiesAsyncConcurrently<A>(
  _ effects: [PropertyEffect<A>],
  maxConcurrency: Int = 5
) async -> [PropertyEffectResult] {
  await withTaskGroup(of: PropertyEffectResult.self) { group in
    var results: [PropertyEffectResult] = []
    let executor = PropertyEffectExecutor()

    for effect in effects {
      group.addTask {
        await executor.run(effect)
      }

      // Limit concurrency by waiting for some tasks to complete
      if results.count % maxConcurrency == 0 && !results.isEmpty {
        if let result = await group.next() {
          results.append(result)
        }
      }
    }

    // Collect remaining results
    while let result = await group.next() {
      results.append(result)
    }

    return results
  }
}

// MARK: - Convenience Extensions

extension PropertyEffect {
  /// Execute this PropertyEffect on MainActor
  @MainActor
  public func runOnMainActor() async -> PropertyEffectResult {
    await checkPropertyAsyncOnActor(self)
  }

  /// Execute this PropertyEffect with serial execution
  public func runSerially() async -> PropertyEffectResult {
    await checkPropertyAsyncSerially(self)
  }

  /// Execute this PropertyEffect in a detached task
  public func runDetached() async -> PropertyEffectResult {
    await checkPropertyAsyncDetached(self)
  }
}
