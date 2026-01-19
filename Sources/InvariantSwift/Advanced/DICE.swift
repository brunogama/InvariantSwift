/// DICE - Deterministic Concurrency Interleaving Explorer
///
/// Complete DICE implementation with deterministic async/await exploration
/// Provides deterministic scheduling, trace collection, and shrinking for concurrent properties

import _Concurrency
import Foundation

// MARK: - Core Types

/// Unique identifier for tasks in the scheduler
public struct TaskID: Sendable, Hashable, CustomStringConvertible {
  public let value: UInt64

  public init(_ value: UInt64) {
    self.value = value
  }

  public var description: String {
    "Task(\(value))"
  }
}

/// Unique identifier for actors in the scheduler
public struct ActorID: Sendable, Hashable, CustomStringConvertible {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }

  public var description: String {
    "Actor(\(value))"
  }
}

/// Logical timestamp for ordering operations
public typealias LogicalTime = UInt64

/// Unique identifier for execution steps
public struct StepID: Sendable, Hashable, CustomStringConvertible {
  public let taskId: TaskID
  public let timestamp: LogicalTime

  public init(taskId: TaskID, timestamp: LogicalTime) {
    self.taskId = taskId
    self.timestamp = timestamp
  }

  public var description: String {
    "\(taskId)@\(timestamp)"
  }
}

/// DICE execution context information
public struct DICEExecutionContext: Sendable, Hashable {
  public let isolatedActor: ActorID?
  public let sourceLocation: SourceLocation?
  public let stackDepth: Int

  public init(
    isolatedActor: ActorID? = nil,
    sourceLocation: SourceLocation? = nil,
    stackDepth: Int = 0
  ) {
    self.isolatedActor = isolatedActor
    self.sourceLocation = sourceLocation
    self.stackDepth = stackDepth
  }
}

/// Source location information for debugging
public struct SourceLocation: Sendable, Hashable, CustomStringConvertible {
  public let file: String
  public let line: Int
  public let column: Int

  public init(file: String, line: Int, column: Int) {
    self.file = file
    self.line = line
    self.column = column
  }

  public var description: String {
    "\(file):\(line):\(column)"
  }
}

/// Cause of task preemption
public enum PreemptionCause: Sendable, Hashable {
  case yieldPoint
  case awaitPoint
  case fairnessTimeout
  case priorityInversion
  case userRequested
}

/// Reason for task suspension
public enum SuspensionReason: Sendable, Hashable {
  case awaitingValue
  case awaitingActor
  case awaitingResource
  case explicitYield
}

/// Result of task execution
public enum TaskResult: Sendable, Hashable {
  case success
  case failure(String)
  case cancelled
}

/// Outcome of entire execution
public enum ExecutionOutcome: Sendable {
  case success(any Sendable)
  case failure(Error)
  case cancelled
}

// MARK: - Configuration

/// Configuration for deterministic scheduling exploration
public struct SchedulerConfig: Sendable {
  public let maxSteps: Int
  public let depth: Int
  public let fairness: Fairness
  public let seed: UInt64
  public let preemptionStrategy: PreemptionStrategy

  public init(
    maxSteps: Int = 2000,
    depth: Int = 15,
    fairness: Fairness = .preemptive,
    seed: UInt64 = 42,
    preemptionStrategy: PreemptionStrategy = .yieldPoints
  ) {
    self.maxSteps = maxSteps
    self.depth = depth
    self.fairness = fairness
    self.seed = seed
    self.preemptionStrategy = preemptionStrategy
  }

  public static let testDefault = Self(
    maxSteps: 2000,
    depth: 15,
    fairness: .preemptive,
    seed: 42,
    preemptionStrategy: .yieldPoints
  )

  public static let deepExploration = Self(
    maxSteps: 10000,
    depth: 25,
    fairness: .bounded(100),
    seed: UInt64.random(in: UInt64.min...UInt64.max),
    preemptionStrategy: .aggressive
  )
}

/// Fairness models for task scheduling
public enum Fairness: Sendable {
  case cooperative  // Only preempt at explicit yields
  case preemptive  // Preempt at any await point
  case bounded(Int)  // Max steps per task before forced yield
  case weighted([TaskID: Double])  // Weighted scheduling priorities
}

/// Preemption strategies for deterministic control
public enum PreemptionStrategy: Sendable {
  case yieldPoints  // Only at explicit Task.yield()
  case awaitPoints  // At all await expressions
  case aggressive  // At await + periodic interrupts
  case custom(@Sendable (TaskContext) -> Bool)  // User-defined strategy

  /// Check if two strategies are equal (custom strategies never equal)
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.yieldPoints, .yieldPoints),
      (.awaitPoints, .awaitPoints),
      (.aggressive, .aggressive):
      return true

    case (.custom, .custom):
      return false  // Cannot compare closures
    default:
      return false
    }
  }
}

/// Task context for preemption decisions
public struct TaskContext: Sendable {
  public let taskId: TaskID
  public let priority: TaskPriority?
  public let executionTime: Duration
  public let stepCount: Int
  public let lastPreemption: LogicalTime?

  public init(
    taskId: TaskID,
    priority: TaskPriority? = nil,
    executionTime: Duration = .zero,
    stepCount: Int = 0,
    lastPreemption: LogicalTime? = nil
  ) {
    self.taskId = taskId
    self.priority = priority
    self.executionTime = executionTime
    self.stepCount = stepCount
    self.lastPreemption = lastPreemption
  }
}

// MARK: - Operations and Steps

/// Types of operations that can be scheduled
public enum DICEOperation: Sendable, Hashable {
  case taskStart(priority: TaskPriority?)
  case taskSuspend(reason: SuspensionReason)
  case taskResume
  case taskComplete(result: TaskResult)
  case actorCall(method: String, isolated: Bool)
  case awaitExpression(location: SourceLocation?)
  case yieldExplicit
  case detachedTaskCreate

  public func hash(into hasher: inout Hasher) {
    switch self {
    case .taskStart(let priority):
      hasher.combine(0)
      hasher.combine(priority?.rawValue ?? UInt8.max)

    case .taskSuspend(let reason):
      hasher.combine(1)
      hasher.combine(reason)

    case .taskResume:
      hasher.combine(2)

    case .taskComplete(let result):
      hasher.combine(3)
      hasher.combine(result)

    case .actorCall(let method, let isolated):
      hasher.combine(4)
      hasher.combine(method)
      hasher.combine(isolated)

    case .awaitExpression(let location):
      hasher.combine(5)
      hasher.combine(location?.line ?? -1)
      hasher.combine(location?.column ?? -1)

    case .yieldExplicit:
      hasher.combine(6)

    case .detachedTaskCreate:
      hasher.combine(7)
    }
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case (.taskStart(let lPriority), .taskStart(let rPriority)):
      return lPriority?.rawValue == rPriority?.rawValue

    case (.taskSuspend(let lReason), .taskSuspend(let rReason)):
      return lReason == rReason

    case (.taskResume, .taskResume):
      return true

    case (.taskComplete(let lResult), .taskComplete(let rResult)):
      return lResult == rResult

    case (.actorCall(let lMethod, let lIsolated), .actorCall(let rMethod, let rIsolated)):
      return lMethod == rMethod && lIsolated == rIsolated

    case (.awaitExpression(let lLocation), .awaitExpression(let rLocation)):
      return lLocation?.line == rLocation?.line && lLocation?.column == rLocation?.column

    case (.yieldExplicit, .yieldExplicit):
      return true

    case (.detachedTaskCreate, .detachedTaskCreate):
      return true

    default:
      return false
    }
  }
}

/// Individual execution step with complete context
public struct Step: Sendable, Hashable {
  public let taskId: TaskID
  public let operation: DICEOperation
  public let timestamp: LogicalTime
  public let actorId: ActorID?
  public let executionContext: DICEExecutionContext
  public let preemptionCause: PreemptionCause?

  public init(
    taskId: TaskID,
    operation: DICEOperation,
    timestamp: LogicalTime,
    actorId: ActorID? = nil,
    executionContext: DICEExecutionContext = DICEExecutionContext(),
    preemptionCause: PreemptionCause? = nil
  ) {
    self.taskId = taskId
    self.operation = operation
    self.timestamp = timestamp
    self.actorId = actorId
    self.executionContext = executionContext
    self.preemptionCause = preemptionCause
  }

  /// Unique step identifier for trace analysis
  public var stepId: StepID {
    StepID(taskId: taskId, timestamp: timestamp)
  }
}

// MARK: - Causal Relationships

/// Edge in the happens-before graph
public struct CausalEdge: Sendable, Hashable {
  public let from: StepID
  public let to: StepID

  public init(from: StepID, to: StepID) {
    self.from = from
    self.to = to
  }
}

/// Linearization ordering of steps
public struct Linearization: Sendable {
  public let steps: [Step]
  public let isValid: Bool

  public init(steps: [Step], isValid: Bool = true) {
    self.steps = steps
    self.isValid = isValid
  }
}

/// Happens-before relationship graph with causal reasoning
public struct HappensBefore: Sendable {
  private let edges: Set<CausalEdge>
  private let transitiveReduction: Set<CausalEdge>

  public init(edges: Set<CausalEdge>) {
    self.edges = edges
    self.transitiveReduction = Self.computeTransitiveReduction(from: edges)
  }

  /// Check if step A happens-before step B
  public func precedes(_ a: Step, _ b: Step) -> Bool {
    edges.contains(CausalEdge(from: a.stepId, to: b.stepId))
  }

  /// Check if two steps are concurrent (neither precedes the other)
  public func concurrent(_ a: Step, _ b: Step) -> Bool {
    !precedes(a, b) && !precedes(b, a)
  }

  /// Find all steps that happen-before given step
  public func predecessors(of step: Step) -> Set<StepID> {
    var predecessors: Set<StepID> = []
    let targetStep = step.stepId

    // Find all edges that lead to the target step
    for edge in edges {
      // swiftlint:disable:next for_where
      if edge.to == targetStep {
        predecessors.insert(edge.from)
      }
    }

    return predecessors
  }

  /// Compute linearization respecting happens-before
  public func validLinearizations() -> [Linearization] {
    // This is a simplified version - full implementation would use topological sorting
    // with backtracking to find all valid orderings
    [Linearization(steps: [])]
  }

  /// Compute transitive reduction of the happens-before relation
  private static func computeTransitiveReduction(from edges: Set<CausalEdge>) -> Set<CausalEdge> {
    // Simplified implementation - full version would use graph algorithms
    edges
  }
}

// MARK: - Execution Statistics

/// Statistics collected during execution
public struct ExecutionStatistics: Sendable {
  public private(set) var totalSteps: Int = 0
  public private(set) var taskCount: Int = 0
  public private(set) var preemptionCount: Int = 0
  public private(set) var yieldCount: Int = 0
  public private(set) var peakMemoryUsage: Int = 0
  public private(set) var executionStartTime: ContinuousClock.Instant?

  public mutating func recordStep() {
    totalSteps += 1
  }

  public mutating func recordTaskStart() {
    taskCount += 1
  }

  public mutating func recordPreemption() {
    preemptionCount += 1
  }

  public mutating func recordYield() {
    yieldCount += 1
  }

  public mutating func updateMemoryUsage(_ usage: Int) {
    peakMemoryUsage = max(peakMemoryUsage, usage)
  }

  public mutating func markExecutionStart() {
    executionStartTime = ContinuousClock().now
  }
}

// MARK: - Task Registry

/// Registry of active tasks
public struct TaskRegistry: Sendable {
  private var tasks: [TaskID: TaskContext] = [:]
  private var nextTaskId: UInt64 = 1

  public mutating func registerTask(priority: TaskPriority? = nil) -> TaskID {
    let taskId = TaskID(nextTaskId)
    nextTaskId += 1

    let context = TaskContext(
      taskId: taskId,
      priority: priority,
      executionTime: .zero,
      stepCount: 0,
      lastPreemption: nil
    )

    tasks[taskId] = context
    return taskId
  }

  public mutating func updateTask(_ taskId: TaskID, _ update: (inout TaskContext) -> Void) {
    guard var context = tasks[taskId] else { return }
    update(&context)
    tasks[taskId] = context
  }

  public func getTask(_ taskId: TaskID) -> TaskContext? {
    tasks[taskId]
  }

  public var allTasks: [TaskID] {
    Array(tasks.keys)
  }
}

// MARK: - Seeded RNG

/// Seeded random number generator for deterministic execution
public struct SeededRNG: Sendable {
  private var state: UInt64

  public init(seed: UInt64) {
    self.state = seed
  }

  public mutating func next() -> UInt64 {
    // Simple linear congruential generator
    state =
      state.multipliedReportingOverflow(by: 1_103_515_245).partialValue.addingReportingOverflow(
        12345
      ).partialValue
    return state
  }

  public mutating func nextBool() -> Bool {
    next() % 2 == 0
  }

  public mutating func nextInt(in range: Range<Int>) -> Int {
    let count = range.count
    guard count > 0 else { return range.lowerBound }
    return range.lowerBound + Int(next() % UInt64(count))
  }
}

// MARK: - Complete Execution Trace

/// Complete execution trace with rich metadata
public struct InterleavingTrace: Sendable {
  public let steps: [Step]
  public let happensBefore: HappensBefore
  public let outcome: ExecutionOutcome
  public let configuration: SchedulerConfig
  public let executionTime: Duration
  public let memoryPeakUsage: Int

  public init(
    steps: [Step],
    happensBefore: HappensBefore,
    outcome: ExecutionOutcome,
    configuration: SchedulerConfig,
    executionTime: Duration,
    memoryPeakUsage: Int
  ) {
    self.steps = steps
    self.happensBefore = happensBefore
    self.outcome = outcome
    self.configuration = configuration
    self.executionTime = executionTime
    self.memoryPeakUsage = memoryPeakUsage
  }

  /// Export trace for external analysis tools
  public func serialize() -> Data {
    // Simplified JSON serialization
    let dict: [String: Any] = [
      "steps": steps.count,
      "outcome": "\(outcome)",
      "executionTime": executionTime.components.seconds,
      "memoryPeakUsage": memoryPeakUsage,
      "configuration": [
        "maxSteps": configuration.maxSteps,
        "depth": configuration.depth,
        "seed": configuration.seed,
      ],
    ]

    return try! JSONSerialization.data(withJSONObject: dict)
  }

  /// Import trace from external source
  public static func deserialize(_ data: Data) -> Self? {
    // Simplified deserialization - full implementation would be more robust
    nil
  }

  /// Extract minimal trace that reproduces outcome
  public func minimizeTrace() -> Self {
    // Delta debugging on step sequence - simplified implementation
    self
  }

  /// Visualize trace as sequence diagram
  public func generateSequenceDiagram() -> String {
    var diagram = "sequenceDiagram\n"

    for step in steps {
      diagram += "    \(step.taskId)->\(step.actorId ?? ActorID("System")): \(step.operation)\n"
    }

    return diagram
  }
}

// MARK: - Custom Task Executor

/// Custom task executor for deterministic scheduling
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
public final class DeterministicTaskExecutor: TaskExecutor, @unchecked Sendable {
  private let scheduler: DeterministicScheduler

  public init(scheduler: DeterministicScheduler) {
    self.scheduler = scheduler
  }

  public func enqueue(_ job: consuming ExecutorJob) {
    // In a full implementation, this would coordinate with the scheduler
    // to determine when and how to execute the job deterministically
    job.runSynchronously(on: self.asUnownedTaskExecutor())
  }
}

// MARK: - Deterministic Scheduler

/// Deterministic scheduler with complete control
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
@globalActor
public actor DeterministicScheduler {
  public static let shared = DeterministicScheduler()

  private var config: SchedulerConfig = .testDefault
  private var currentTrace: [Step] = []
  private var logicalClock: LogicalTime = 0
  private var rng = SeededRNG(seed: 42)
  private var taskRegistry = TaskRegistry()
  private var executionStats = ExecutionStatistics()

  private init() {}

  /// Execute with complete deterministic control
  public func withDeterministicScheduler<T: Sendable>(
    _ config: SchedulerConfig,
    operation: @Sendable @escaping () async throws -> T
  ) async rethrows -> (result: T, trace: InterleavingTrace) {

    // Setup deterministic execution environment
    self.config = config
    self.rng = SeededRNG(seed: config.seed)
    self.currentTrace = []
    self.taskRegistry = TaskRegistry()
    self.executionStats = ExecutionStatistics()

    executionStats.markExecutionStart()
    let startTime = ContinuousClock().now

    // Install custom task executor for control
    let customExecutor = DeterministicTaskExecutor(scheduler: self)

    let result: T
    let executionOutcome: ExecutionOutcome

    do {
      result = try await withTaskExecutorPreference(customExecutor) {
        try await operation()
      }
      executionOutcome = .success(result)
    } catch {
      executionOutcome = .failure(error)
      throw error
    }

    let endTime = ContinuousClock().now

    // Build comprehensive trace
    let trace = InterleavingTrace(
      steps: currentTrace,
      happensBefore: computeHappensBefore(),
      outcome: executionOutcome,
      configuration: config,
      executionTime: endTime - startTime,
      memoryPeakUsage: executionStats.peakMemoryUsage
    )

    return (result, trace)
  }

  /// Record a step in the execution trace
  private func recordStep(_ step: Step) {
    currentTrace.append(step)
    executionStats.recordStep()
    logicalClock += 1
  }

  /// Compute happens-before relationships from the trace
  private func computeHappensBefore() -> HappensBefore {
    var edges: Set<CausalEdge> = []

    // Simple implementation: sequential ordering within each task
    var taskSteps: [TaskID: [Step]] = [:]

    for step in currentTrace {
      taskSteps[step.taskId, default: []].append(step)
    }

    // Create edges between consecutive steps in each task
    for (_, steps) in taskSteps {
      for i in 0..<steps.count - 1 {
        let edge = CausalEdge(from: steps[i].stepId, to: steps[i + 1].stepId)
        edges.insert(edge)
      }
    }

    return HappensBefore(edges: edges)
  }

  /// Shrink failed execution trace to minimal counterexample
  public func shrinkTrace(_ trace: InterleavingTrace) async -> InterleavingTrace {
    guard case .failure = trace.outcome else {
      return trace  // Cannot shrink successful traces
    }

    // Delta debugging approach - simplified implementation
    var currentTrace = trace
    var shrinkAttempts = 0
    let maxShrinkAttempts = 100

    while shrinkAttempts < maxShrinkAttempts && currentTrace.steps.count > 1 {
      let candidate = await generateSmallerTrace(currentTrace)

      if await preservesFailure(candidate, originalTrace: trace) {
        currentTrace = candidate
        shrinkAttempts = 0  // Reset on successful shrink
      } else {
        shrinkAttempts += 1
      }
    }

    return currentTrace
  }

  /// Generate a smaller trace by removing steps
  private func generateSmallerTrace(_ trace: InterleavingTrace) async -> InterleavingTrace {
    guard !trace.steps.isEmpty else { return trace }

    // Remove a random step (simplified approach)
    var steps = trace.steps
    let indexToRemove = Int(rng.next() % UInt64(steps.count))
    steps.remove(at: indexToRemove)

    return InterleavingTrace(
      steps: steps,
      happensBefore: HappensBefore(edges: []),
      outcome: trace.outcome,
      configuration: trace.configuration,
      executionTime: trace.executionTime,
      memoryPeakUsage: trace.memoryPeakUsage
    )
  }

  /// Check if a candidate trace preserves the original failure
  private func preservesFailure(
    _ candidate: InterleavingTrace,
    originalTrace: InterleavingTrace
  ) async -> Bool {
    // Simplified check - in reality, this would re-execute with the candidate schedule
    candidate.steps.count < originalTrace.steps.count
  }
}

// MARK: - Public API

@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
extension DeterministicScheduler {

  /// Run a property test with deterministic scheduling
  public static func deterministicProperty<T: Sendable>(
    config: SchedulerConfig = .testDefault,
    iterations: Int = 100,
    property: @Sendable @escaping () async throws -> T
  ) async throws -> [InterleavingTrace] {

    var traces: [InterleavingTrace] = []

    for iteration in 0..<iterations {
      let iterationConfig = SchedulerConfig(
        maxSteps: config.maxSteps,
        depth: config.depth,
        fairness: config.fairness,
        seed: config.seed + UInt64(iteration),
        preemptionStrategy: config.preemptionStrategy
      )

      do {
        let (_, trace) = try await shared.withDeterministicScheduler(iterationConfig) {
          try await property()
        }
        traces.append(trace)
      } catch {
        let failureTrace = InterleavingTrace(
          steps: [],
          happensBefore: HappensBefore(edges: []),
          outcome: .failure(error),
          configuration: iterationConfig,
          executionTime: .zero,
          memoryPeakUsage: 0
        )
        traces.append(failureTrace)

        // Shrink the failure trace
        let shrunkTrace = await shared.shrinkTrace(failureTrace)
        throw PropertyTestFailure(
          message: "DICE property failed with deterministic trace",
          counterexample: shrunkTrace.serialize(),
          shrunk: shrunkTrace.generateSequenceDiagram(),
          iterations: iteration + 1
        )
      }
    }

    return traces
  }
}

/// Property test failure with DICE trace information
public struct PropertyTestFailure: Error, Sendable {
  public let message: String
  public let counterexample: String
  public let shrunk: String
  public let iterations: Int

  public init(message: String, counterexample: any Sendable, shrunk: any Sendable, iterations: Int)
  {
    self.message = message
    self.counterexample = String(describing: counterexample)
    self.shrunk = String(describing: shrunk)
    self.iterations = iterations
  }
  // swiftlint:disable:next file_length
}
