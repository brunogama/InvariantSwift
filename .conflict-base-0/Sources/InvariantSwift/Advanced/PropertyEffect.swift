/// PropertyEffect<A> - Actor-Integrated Property Testing Framework
///
/// Advanced property-based testing system that integrates deeply with Swift's Actor model
/// to provide deterministic, isolated, and concurrent property testing capabilities.
/// This is part of Phase 2: Intelligence & Automation Layer.

import Foundation

// MARK: - Core PropertyEffect Type

/// Represents an effectful property test that can be executed on specific actors
/// with full isolation guarantees and deterministic behavior.
public struct PropertyEffect<A>: Sendable where A: Sendable {
  public let generator: Gen<A>
  public let effect: @Sendable (A) async throws -> Bool
  public let actorIsolation: ActorIsolationStrategy
  public let config: EffectConfig

  public init(
    generator: Gen<A>,
    effect: @escaping @Sendable (A) async throws -> Bool,
    actorIsolation: ActorIsolationStrategy = .mainActor,
    config: EffectConfig = .default
  ) {
    self.generator = generator
    self.effect = effect
    self.actorIsolation = actorIsolation
    self.config = config
  }

  /// Create PropertyEffect with custom actor isolation
  public static func isolatedOn<ActorType: Actor>(
    _ actorType: ActorType.Type,
    generator: Gen<A>,
    effect: @escaping @Sendable (A) async throws -> Bool,
    config: EffectConfig = .default
  ) -> PropertyEffect<A> {
    Self(
      generator: generator,
      effect: effect,
      actorIsolation: .customActor(String(describing: actorType)),
      config: config
    )
  }

  /// Create PropertyEffect for MainActor isolation
  public static func onMainActor(
    generator: Gen<A>,
    effect: @escaping @Sendable (A) async throws -> Bool,
    config: EffectConfig = .default
  ) -> PropertyEffect<A> {
    Self(
      generator: generator,
      effect: effect,
      actorIsolation: .mainActor,
      config: config
    )
  }

  /// Create PropertyEffect with global actor isolation
  public static func onGlobalActor<GA: GlobalActor>(
    _ globalActor: GA.Type,
    generator: Gen<A>,
    effect: @escaping @Sendable (A) async throws -> Bool,
    config: EffectConfig = .default
  ) -> PropertyEffect<A> {
    Self(
      generator: generator,
      effect: effect,
      actorIsolation: .globalActor(String(describing: globalActor)),
      config: config
    )
  }
}

// MARK: - Actor Isolation Strategy

/// Defines how property effects should be isolated across actors
public enum ActorIsolationStrategy: Sendable {
  case mainActor
  case globalActor(String)  // Store type name as string for Sendable compliance
  case customActor(String)  // Store type name as string for Sendable compliance
  case serialExecutor
  case detachedTask
  case taskGroup(maxConcurrency: Int)

  /// Actor context information for debugging and tracing
  public var description: String {
    switch self {
    case .mainActor: return "MainActor"
    case .globalActor(let typeName): return "GlobalActor(\(typeName))"
    case .customActor(let typeName): return "Actor(\(typeName))"
    case .serialExecutor: return "SerialExecutor"
    case .detachedTask: return "DetachedTask"
    case .taskGroup(let maxConcurrency): return "TaskGroup(maxConcurrency: \(maxConcurrency))"
    }
  }
}

// MARK: - Effect Configuration

/// Configuration for PropertyEffect execution behavior
public struct EffectConfig: Sendable {
  public let iterations: Int
  public let timeout: Duration
  public let retryStrategy: RetryStrategy
  public let isolationValidation: IsolationValidation
  public let tracing: TracingConfig

  public init(
    iterations: Int = 100,
    timeout: Duration = .seconds(30),
    retryStrategy: RetryStrategy = .noRetry,
    isolationValidation: IsolationValidation = .strict,
    tracing: TracingConfig = .disabled
  ) {
    self.iterations = max(1, iterations)
    self.timeout = timeout
    self.retryStrategy = retryStrategy
    self.isolationValidation = isolationValidation
    self.tracing = tracing
  }

  public static let `default` = Self()
  public static let strict = Self(
    iterations: 1000,
    timeout: .seconds(60),
    isolationValidation: .strict,
    tracing: .detailed
  )
}

/// Retry strategy for failed property effects
public enum RetryStrategy: Sendable {
  case noRetry
  case fixedDelay(Duration, maxAttempts: Int)
  case exponentialBackoff(base: Duration, maxAttempts: Int, maxDelay: Duration)
  case customStrategy(@Sendable (Int) async -> Duration?)

  /// Calculate delay for attempt number (0-indexed)
  public func delay(for attempt: Int) async -> Duration? {
    switch self {
    case .noRetry:
      return nil

    case .fixedDelay(let delay, let maxAttempts):
      return attempt < maxAttempts ? delay : nil

    case .exponentialBackoff(let base, let maxAttempts, let maxDelay):
      guard attempt < maxAttempts else { return nil }
      let multiplier = Int64(pow(2.0, Double(attempt)))
      let exponentialDelay = Duration.nanoseconds(
        base.components.seconds * 1_000_000_000 * multiplier + base.components.attoseconds
          / 1_000_000_000 * multiplier
      )
      return min(exponentialDelay, maxDelay)

    case .customStrategy(let strategy):
      return await strategy(attempt)
    }
  }
}

/// Actor isolation validation level
public enum IsolationValidation: Sendable {
  case disabled  // No isolation checking
  case basic  // Basic actor boundary validation
  case strict  // Comprehensive isolation verification
  case custom(@Sendable (Any.Type, Any.Type) -> Bool)  // Custom validation logic
}

extension IsolationValidation: Equatable {
  public static func == (lhs: IsolationValidation, rhs: IsolationValidation) -> Bool {
    switch (lhs, rhs) {
    case (.disabled, .disabled), (.basic, .basic), (.strict, .strict):
      return true

    case (.custom, .custom):
      return false  // Custom functions can't be compared for equality
    default:
      return false
    }
  }
}

/// Tracing configuration for property effect execution
public enum TracingConfig: Sendable {
  case disabled
  case basic
  case detailed
  case custom(TracingOptions)
}

public struct TracingOptions: Sendable {
  public let includeActorSwitches: Bool
  public let includeTaskCreation: Bool
  public let includeIsolationValidation: Bool
  public let includePerformanceMetrics: Bool

  public init(
    includeActorSwitches: Bool = true,
    includeTaskCreation: Bool = true,
    includeIsolationValidation: Bool = true,
    includePerformanceMetrics: Bool = false
  ) {
    self.includeActorSwitches = includeActorSwitches
    self.includeTaskCreation = includeTaskCreation
    self.includeIsolationValidation = includeIsolationValidation
    self.includePerformanceMetrics = includePerformanceMetrics
  }
}

// MARK: - PropertyEffect Result Types

/// Result of executing a PropertyEffect
public struct PropertyEffectResult: Sendable {
  public let success: Bool
  public let iterations: Int
  public let failures: [PropertyEffectFailure]
  public let executionMetrics: ExecutionMetrics
  public let isolationReport: IsolationReport

  public init(
    success: Bool,
    iterations: Int,
    failures: [PropertyEffectFailure],
    executionMetrics: ExecutionMetrics,
    isolationReport: IsolationReport
  ) {
    self.success = success
    self.iterations = iterations
    self.failures = failures
    self.executionMetrics = executionMetrics
    self.isolationReport = isolationReport
  }

  /// Create successful result
  public static func success(
    iterations: Int,
    metrics: ExecutionMetrics,
    isolationReport: IsolationReport
  ) -> Self {
    Self(
      success: true,
      iterations: iterations,
      failures: [],
      executionMetrics: metrics,
      isolationReport: isolationReport
    )
  }

  /// Create failed result
  public static func failure(
    iterations: Int,
    failures: [PropertyEffectFailure],
    metrics: ExecutionMetrics,
    isolationReport: IsolationReport
  ) -> Self {
    Self(
      success: false,
      iterations: iterations,
      failures: failures,
      executionMetrics: metrics,
      isolationReport: isolationReport
    )
  }
}

/// Detailed failure information for PropertyEffect execution
public struct PropertyEffectFailure: Error, Sendable {
  public let iteration: Int
  public let input: String  // String representation of input
  public let error: String  // Error description
  public let actorContext: String
  public let isolationViolation: Bool
  public let timestamp: ContinuousClock.Instant

  public init(
    iteration: Int,
    input: String,
    error: String,
    actorContext: String,
    isolationViolation: Bool = false,
    timestamp: ContinuousClock.Instant = ContinuousClock.now
  ) {
    self.iteration = iteration
    self.input = input
    self.error = error
    self.actorContext = actorContext
    self.isolationViolation = isolationViolation
    self.timestamp = timestamp
  }
}

/// Execution performance and behavior metrics
public struct ExecutionMetrics: Sendable {
  public let totalDuration: Duration
  public let averageIterationTime: Duration
  public let actorSwitches: Int
  public let taskCreations: Int
  public let maxConcurrentTasks: Int
  public let memoryPressure: MemoryPressureLevel

  public init(
    totalDuration: Duration,
    averageIterationTime: Duration,
    actorSwitches: Int,
    taskCreations: Int,
    maxConcurrentTasks: Int,
    memoryPressure: MemoryPressureLevel
  ) {
    self.totalDuration = totalDuration
    self.averageIterationTime = averageIterationTime
    self.actorSwitches = actorSwitches
    self.taskCreations = taskCreations
    self.maxConcurrentTasks = maxConcurrentTasks
    self.memoryPressure = memoryPressure
  }
}

public enum MemoryPressureLevel: Sendable {
  case normal
  case elevated
  case critical
}

/// Actor isolation compliance report
public struct IsolationReport: Sendable {
  public let expectedActor: String
  public let actualExecutionContexts: [String]
  public let isolationViolations: [IsolationViolation]
  public let complianceScore: Double  // 0.0 to 1.0

  public init(
    expectedActor: String,
    actualExecutionContexts: [String],
    isolationViolations: [IsolationViolation],
    complianceScore: Double
  ) {
    self.expectedActor = expectedActor
    self.actualExecutionContexts = actualExecutionContexts
    self.isolationViolations = isolationViolations
    self.complianceScore = max(0.0, min(1.0, complianceScore))
  }

  public var isCompliant: Bool {
    isolationViolations.isEmpty && complianceScore >= 0.95
  }
}

public struct IsolationViolation: Sendable {
  public let iteration: Int
  public let expectedActor: String
  public let actualActor: String
  public let violationType: ViolationType

  public enum ViolationType: Sendable {
    case unexpectedActorSwitch
    case crossActorDataAccess
    case racyExecution
    case suspensionPointViolation
  }

  public init(
    iteration: Int,
    expectedActor: String,
    actualActor: String,
    violationType: ViolationType
  ) {
    self.iteration = iteration
    self.expectedActor = expectedActor
    self.actualActor = actualActor
    self.violationType = violationType
  }
}

// MARK: - PropertyEffect Extensions

extension PropertyEffect {
  /// Run the PropertyEffect with full actor isolation and tracing
  public func run() async -> PropertyEffectResult {
    let executor = PropertyEffectExecutor()
    return await executor.run(self)
  }

  /// Create a new PropertyEffect with a different input type by providing both
  /// a transform and a new generator for that input type.
  ///
  /// - Parameters:
  ///   - generator: A generator for the new input type B
  ///   - transform: A function to transform B values to A values
  /// - Returns: A new PropertyEffect that generates B values and transforms them to A for testing
  ///
  /// - Note: Standard contramap requires only the transform, but since we need to generate
  ///   values, a generator for B must also be provided.
  public func contramapWith<B>(
    generator newGenerator: Gen<B>,
    _ transform: @escaping @Sendable (B) -> A
  ) -> PropertyEffect<B> where B: Sendable {
    PropertyEffect<B>(
      generator: newGenerator,
      effect: { b in
        try await self.effect(transform(b))
      },
      actorIsolation: actorIsolation,
      config: config
    )
  }

  /// Combine with another PropertyEffect using logical AND
  public func and<B>(_ other: PropertyEffect<B>) -> PropertyEffect<(A, B)> where B: Sendable {
    PropertyEffect<(A, B)>(
      generator: Gen<(A, B)>.zip(generator, other.generator),
      effect: { a, b in
        let selfResult = try await self.effect(a)
        let otherResult = try await other.effect(b)
        return selfResult && otherResult
      },
      actorIsolation: actorIsolation,  // Use primary effect's isolation
      config: config
    )
  }
}

// MARK: - Gen Extension for PropertyEffect

extension Gen where T: Sendable {
  /// Create a PropertyEffect from this generator
  public func propertyEffect(
    _ effect: @escaping @Sendable (T) async throws -> Bool,
    actorIsolation: ActorIsolationStrategy = .mainActor,
    config: EffectConfig = .default
  ) -> PropertyEffect<T> {
    PropertyEffect(
      generator: self,
      effect: effect,
      actorIsolation: actorIsolation,
      config: config
    )
  }
}
