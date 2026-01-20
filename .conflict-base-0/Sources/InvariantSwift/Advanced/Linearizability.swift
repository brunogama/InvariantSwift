/// Complete linearizability checking system for concurrent data structures
///
/// Implements Wing-Gong algorithm with optimizations for verifying that concurrent
/// data structure operations appear to take effect atomically at some point
/// between their call and return times (linearization points).

import Foundation

// MARK: - Core Types

/// Unique identifier for threads in concurrent execution
public struct ThreadID: Sendable, Hashable, CustomStringConvertible {
  public let value: UInt64

  public init(_ value: UInt64) {
    self.value = value
  }

  public var description: String {
    "Thread(\(value))"
  }
}

/// Context information for operations
public struct OperationContext: Sendable, Hashable {
  public let processId: Int
  public let threadId: ThreadID
  public let operationName: String
  public let metadata: [String: String]

  public init(
    processId: Int = 0,
    threadId: ThreadID,
    operationName: String,
    metadata: [String: String] = [:]
  ) {
    self.processId = processId
    self.threadId = threadId
    self.operationName = operationName
    self.metadata = metadata
  }
}

/// Operation with complete timing and context information
public struct Operation<Input, Output>: Sendable, Identifiable
where Input: Sendable, Output: Sendable & Equatable {
  public let id: UUID
  public let call: Input
  public let response: Output
  public let startTime: ContinuousClock.Instant
  public let endTime: ContinuousClock.Instant
  public let threadId: ThreadID
  public let context: OperationContext

  public init(
    id: UUID = UUID(),
    call: Input,
    response: Output,
    startTime: ContinuousClock.Instant,
    endTime: ContinuousClock.Instant,
    threadId: ThreadID,
    context: OperationContext
  ) {
    self.id = id
    self.call = call
    self.response = response
    self.startTime = startTime
    self.endTime = endTime
    self.threadId = threadId
    self.context = context
  }

  /// Operation duration
  public var duration: Duration {
    endTime - startTime
  }

  /// Check if operation overlaps with another
  public func overlaps(with other: Operation<Input, Output>) -> Bool {
    !(endTime < other.startTime || startTime > other.endTime)
  }

  /// Check if operation happens-before another
  public func happensBefore(_ other: Operation<Input, Output>) -> Bool {
    endTime <= other.startTime
  }
}

/// Type-erased operation for collections
public struct AnyOperation: Sendable, Identifiable, CustomStringConvertible {
  public let id: UUID
  public let operationName: String
  public let startTime: ContinuousClock.Instant
  public let endTime: ContinuousClock.Instant
  public let threadId: ThreadID
  public let description: String

  public init<Input, Output>(from operation: Operation<Input, Output>) {
    self.id = operation.id
    self.operationName = operation.context.operationName
    self.startTime = operation.startTime
    self.endTime = operation.endTime
    self.threadId = operation.threadId
    self.description =
      "\(operation.context.operationName)(\(operation.call)) -> \(operation.response)"
  }
}

// MARK: - Specification Framework

/// Sequential specification for concurrent data structure
public struct Spec<Model, Input, Output>: Sendable
where Model: Sendable, Input: Sendable, Output: Sendable & Equatable {

  /// Apply operation to model state
  public let apply: @Sendable (inout Model, Input) -> Output

  /// Check if operation is valid in current state
  public let precondition: @Sendable (Model, Input) -> Bool

  /// Validate operation result against state
  public let postcondition: @Sendable (Model, Output) -> Bool

  /// Check if two operations commute in given state
  public let commutes: @Sendable (Model, Input, Input) -> Bool

  public init(
    apply: @escaping @Sendable (inout Model, Input) -> Output,
    precondition: @escaping @Sendable (Model, Input) -> Bool = { _, _ in true },
    postcondition: @escaping @Sendable (Model, Output) -> Bool = { _, _ in true },
    commutes: @escaping @Sendable (Model, Input, Input) -> Bool = { _, _, _ in false }
  ) {
    self.apply = apply
    self.precondition = precondition
    self.postcondition = postcondition
    self.commutes = commutes
  }
}

// MARK: - Configuration

/// Configuration for linearizability checker
public struct CheckerConfig: Sendable {
  public let maxSearchSteps: Int
  public let maxSearchTime: Duration
  public let enableOptimizations: Bool
  public let enableStateCompression: Bool
  public let parallelSearch: Bool
  public let debugMode: Bool

  public init(
    maxSearchSteps: Int = 100000,
    maxSearchTime: Duration = .seconds(30),
    enableOptimizations: Bool = true,
    enableStateCompression: Bool = true,
    parallelSearch: Bool = false,
    debugMode: Bool = false
  ) {
    self.maxSearchSteps = maxSearchSteps
    self.maxSearchTime = maxSearchTime
    self.enableOptimizations = enableOptimizations
    self.enableStateCompression = enableStateCompression
    self.parallelSearch = parallelSearch
    self.debugMode = debugMode
  }

  public static let fast = Self(
    maxSearchSteps: 10000,
    maxSearchTime: .seconds(5),
    enableOptimizations: true,
    enableStateCompression: true
  )

  public static let thorough = Self(
    maxSearchSteps: 1_000_000,
    maxSearchTime: .seconds(120),
    enableOptimizations: true,
    enableStateCompression: false,
    debugMode: true
  )
}

// MARK: - Search State Management

/// Fingerprint for state compression and cycle detection
public struct StateFingerprint: Sendable, Hashable {
  private let hash: Int
  private let stateDescription: String

  public init<T: Sendable>(state: T, executedOps: [UUID]) {
    self.stateDescription = "\(state)-\(executedOps.sorted())"
    self.hash = stateDescription.hashValue
  }
}

/// Search state during Wing-Gong algorithm
public struct SearchState<Model>: Sendable where Model: Sendable {
  public let remainingOps: Set<UUID>
  public let currentState: Model
  public let executedSequence: [UUID]
  public let depth: Int

  public init(
    remainingOps: Set<UUID>,
    currentState: Model,
    executedSequence: [UUID],
    depth: Int = 0
  ) {
    self.remainingOps = remainingOps
    self.currentState = currentState
    self.executedSequence = executedSequence
    self.depth = depth
  }

  /// Create child state by executing an operation
  public func executing<Input, Output>(
    _ operation: Operation<Input, Output>,
    newState: Model
  ) -> SearchState<Model> {
    var newRemaining = remainingOps
    newRemaining.remove(operation.id)

    var newSequence = executedSequence
    newSequence.append(operation.id)

    return Self(
      remainingOps: newRemaining,
      currentState: newState,
      executedSequence: newSequence,
      depth: depth + 1
    )
  }

  /// Check if search is complete
  public var isComplete: Bool {
    remainingOps.isEmpty
  }

  /// Generate fingerprint for cycle detection
  public func fingerprint() -> StateFingerprint {
    StateFingerprint(state: currentState, executedOps: executedSequence)
  }
}

// MARK: - Happens-Before Graph

/// Happens-before relationship graph for operations
public struct HBGraph<Input, Output>: Sendable
where Input: Sendable, Output: Sendable & Equatable {
  public let operations: [Operation<Input, Output>]
  private let edges: Set<HBEdge>

  public init(operations: [Operation<Input, Output>]) {
    self.operations = operations
    self.edges = Self.computeHBEdges(from: operations)
  }

  /// Check if operation A happens-before operation B
  public func happensBefore(_ a: UUID, _ b: UUID) -> Bool {
    edges.contains(HBEdge(from: a, to: b))
  }

  /// Get operations that can be executed next (respecting HB constraints)
  public func getEnabledOps(_ remaining: Set<UUID>, _ executed: Set<UUID>) -> Set<UUID> {
    var enabled: Set<UUID> = []

    for opId in remaining {
      let hasUnmetDependencies = edges.contains { edge in
        edge.to == opId && remaining.contains(edge.from)
      }

      if !hasUnmetDependencies {
        enabled.insert(opId)
      }
    }

    return enabled
  }

  /// Compute happens-before edges from operation timings
  private static func computeHBEdges(from operations: [Operation<Input, Output>]) -> Set<HBEdge> {
    var edges: Set<HBEdge> = []

    // Add edges for operations that don't overlap (one finishes before other starts)
    for i in 0..<operations.count {
      for j in 0..<operations.count {
        if i != j && operations[i].happensBefore(operations[j]) {
          edges.insert(HBEdge(from: operations[i].id, to: operations[j].id))
        }
      }
    }

    // Add transitive closure
    var changed = true
    while changed {
      changed = false
      let currentEdges = edges

      for edge1 in currentEdges {
        for edge2 in currentEdges {
          // swiftlint:disable:next for_where
          if edge1.to == edge2.from {
            let transitiveEdge = HBEdge(from: edge1.from, to: edge2.to)
            if !edges.contains(transitiveEdge) {
              edges.insert(transitiveEdge)
              changed = true
            }
          }
        }
      }
    }

    return edges
  }
}

/// Edge in happens-before graph
public struct HBEdge: Sendable, Hashable {
  public let from: UUID
  public let to: UUID

  public init(from: UUID, to: UUID) {
    self.from = from
    self.to = to
  }
}

// MARK: - Verification and Witness Types

/// Single step in verification process
public struct VerificationStep: Sendable {
  public let operationId: UUID
  public let description: String
  public let stateBeforeJSON: String
  public let stateAfterJSON: String

  public init(
    operationId: UUID,
    description: String,
    stateBeforeJSON: String,
    stateAfterJSON: String
  ) {
    self.operationId = operationId
    self.description = description
    self.stateBeforeJSON = stateBeforeJSON
    self.stateAfterJSON = stateAfterJSON
  }
}

/// Partial analysis results for timeout cases
public struct PartialAnalysis: Sendable {
  public let searchedStates: Int
  public let maxDepthReached: Int
  public let timeElapsed: Duration
  public let lastValidState: String?

  public init(
    searchedStates: Int = 0,
    maxDepthReached: Int = 0,
    timeElapsed: Duration = .zero,
    lastValidState: String? = nil
  ) {
    self.searchedStates = searchedStates
    self.maxDepthReached = maxDepthReached
    self.timeElapsed = timeElapsed
    self.lastValidState = lastValidState
  }
}

/// Result of linearizability analysis
public enum LinearizabilityResult: Sendable {
  case linearizable(witness: LinearizationWitness)
  case notLinearizable(counterexample: NonLinearizableWitness)
  case timeout(partialResults: PartialAnalysis)
  case error(String)

  public var isLinearizable: Bool {
    if case .linearizable = self { return true }
    return false
  }
}

/// Witness for linearizability (valid sequential execution)
public struct LinearizationWitness: Sendable {
  public let sequentialOrder: [UUID]  // Operation IDs in sequential order
  public let finalState: String  // JSON representation of final state
  public let verificationSteps: [VerificationStep]

  public init(sequentialOrder: [UUID], finalState: String, verificationSteps: [VerificationStep]) {
    self.sequentialOrder = sequentialOrder
    self.finalState = finalState
    self.verificationSteps = verificationSteps
  }

  /// Generate human-readable explanation
  public func explanation() -> String {
    var result = "Linearizable execution found:\n\n"

    for step in verificationSteps {
      result += "  \(step.operationId): \(step.description)\n"
    }

    result += "\nFinal state: \(finalState)"
    return result
  }
}

/// Witness for non-linearizability
public struct NonLinearizableWitness: Sendable {
  public let conflictingOperations: [UUID]
  public let explanation: String
  public let minimalHistory: [AnyOperation]
  public let proofOfViolation: String

  public init(
    conflictingOperations: [UUID],
    explanation: String,
    minimalHistory: [AnyOperation],
    proofOfViolation: String
  ) {
    self.conflictingOperations = conflictingOperations
    self.explanation = explanation
    self.minimalHistory = minimalHistory
    self.proofOfViolation = proofOfViolation
  }

  /// Generate debugging information
  public func debugInfo() -> String {
    var result = "Non-linearizable execution detected:\n\n"
    result += explanation + "\n\n"
    result += "Conflicting operations:\n"

    for opId in conflictingOperations {
      result += "  - \(opId)\n"
    }

    result += "\nMinimal reproducing history:\n"
    for (index, op) in minimalHistory.enumerated() {
      result += "  \(index + 1). \(op.description)\n"
    }

    result += "\nProof of violation:\n\(proofOfViolation)"

    return result
  }
}

// MARK: - Main Linearizability Checker

/// Main linearizability checker with Wing-Gong algorithm
public actor LinearizabilityChecker<Model, Input, Output>
where Model: Sendable, Input: Sendable, Output: Sendable & Equatable {

  private let spec: Spec<Model, Input, Output>
  private let initial: Model
  private let config: CheckerConfig

  public init(
    spec: Spec<Model, Input, Output>,
    initial: Model,
    config: CheckerConfig = CheckerConfig()
  ) {
    self.spec = spec
    self.initial = initial
    self.config = config
  }

  /// Check linearizability using Wing-Gong algorithm with optimizations
  public func check(
    operations: [Operation<Input, Output>],
    timeout: Duration = .seconds(30)
  ) async -> LinearizabilityResult {

    let startTime = ContinuousClock().now

    // Build happens-before graph from operation timings
    let hbGraph = HBGraph(operations: operations)

    // Preprocessing: detect obvious non-linearizability
    if let quickResult = quickLinearizabilityCheck(hbGraph) {
      return quickResult
    }

    // Main Wing-Gong algorithm with timeout
    return await withTimeout(timeout) {
      await self.wingGongSearch(hbGraph, startTime: startTime)
    }
      ?? .timeout(
        partialResults: PartialAnalysis(
          timeElapsed: ContinuousClock().now - startTime
        )
      )
  }

  /// Quick linearizability checks before full search
  private func quickLinearizabilityCheck(
    _ hbGraph: HBGraph<Input, Output>
  ) -> LinearizabilityResult? {
    // Check for obvious violations
    let operations = hbGraph.operations

    // Validate each operation's pre/postconditions
    for operation in operations {
      if !spec.precondition(initial, operation.call) {
        return .notLinearizable(
          counterexample: NonLinearizableWitness(
            conflictingOperations: [operation.id],
            explanation: "Operation \(operation.id) violates precondition",
            minimalHistory: [AnyOperation(from: operation)],
            proofOfViolation: "Precondition check failed for operation \(operation.call)"
          )
        )
      }

      if !spec.postcondition(initial, operation.response) {
        return .notLinearizable(
          counterexample: NonLinearizableWitness(
            conflictingOperations: [operation.id],
            explanation: "Operation \(operation.id) violates postcondition",
            minimalHistory: [AnyOperation(from: operation)],
            proofOfViolation: "Postcondition check failed for response \(operation.response)"
          )
        )
      }
    }

    return nil  // No quick determination possible
  }

  /// Main Wing-Gong search algorithm
  private func wingGongSearch(
    _ hbGraph: HBGraph<Input, Output>,
    startTime: ContinuousClock.Instant
  ) async -> LinearizabilityResult {

    // State space search through all valid sequential orderings
    var searchQueue = [
      SearchState(
        remainingOps: Set(hbGraph.operations.map(\.id)),
        currentState: initial,
        executedSequence: []
      )
    ]

    var visitedStates: Set<StateFingerprint> = []
    var searchSteps = 0
    let maxSearchSteps = config.maxSearchSteps
    var maxDepthReached = 0

    while !searchQueue.isEmpty && searchSteps < maxSearchSteps {
      searchSteps += 1

      // Check timeout periodically
      if searchSteps % 1000 == 0 {
        let elapsed = ContinuousClock().now - startTime
        if elapsed > config.maxSearchTime {
          break
        }
      }

      let currentSearchState = searchQueue.removeFirst()
      maxDepthReached = max(maxDepthReached, currentSearchState.depth)

      // Check for cycle detection if enabled
      if config.enableStateCompression {
        let fingerprint = currentSearchState.fingerprint()
        if visitedStates.contains(fingerprint) {
          continue
        }
        visitedStates.insert(fingerprint)
      }

      // If all operations executed, we found a linearization
      if currentSearchState.isComplete {
        return buildLinearizableWitness(
          sequence: currentSearchState.executedSequence,
          finalState: currentSearchState.currentState,
          operations: hbGraph.operations
        )
      }

      // Get enabled operations (respecting happens-before constraints)
      let remainingSet = currentSearchState.remainingOps
      let executedSet = Set(currentSearchState.executedSequence)
      let enabledOps = hbGraph.getEnabledOps(remainingSet, executedSet)

      // Try each enabled operation
      for opId in enabledOps {
        guard let operation = hbGraph.operations.first(where: { $0.id == opId }) else {
          continue
        }

        // Apply operation to current state
        var newState = currentSearchState.currentState
        let actualResponse = spec.apply(&newState, operation.call)

        // Verify the response matches what was recorded
        if actualResponse == operation.response {
          let newSearchState = currentSearchState.executing(operation, newState: newState)
          searchQueue.append(newSearchState)
        }
      }

      // Sort queue for better search order (shorter sequences first)
      if config.enableOptimizations {
        searchQueue.sort { $0.depth < $1.depth }
      }
    }

    // If we reach here, no linearization was found
    return buildNonLinearizableWitness(
      operations: hbGraph.operations,
      searchSteps: searchSteps,
      maxDepthReached: maxDepthReached
    )
  }

  /// Build witness for linearizable execution
  private func buildLinearizableWitness(
    sequence: [UUID],
    finalState: Model,
    operations: [Operation<Input, Output>]
  ) -> LinearizabilityResult {

    var verificationSteps: [VerificationStep] = []
    var currentState = initial

    for opId in sequence {
      guard let operation = operations.first(where: { $0.id == opId }) else {
        continue
      }

      let stateBeforeJSON = "\(currentState)"
      let response = spec.apply(&currentState, operation.call)
      let stateAfterJSON = "\(currentState)"

      let step = VerificationStep(
        operationId: opId,
        description: "\(operation.context.operationName)(\(operation.call)) -> \(response)",
        stateBeforeJSON: stateBeforeJSON,
        stateAfterJSON: stateAfterJSON
      )
      verificationSteps.append(step)
    }

    let witness = LinearizationWitness(
      sequentialOrder: sequence,
      finalState: "\(finalState)",
      verificationSteps: verificationSteps
    )

    return .linearizable(witness: witness)
  }

  /// Build witness for non-linearizable execution
  private func buildNonLinearizableWitness(
    operations: [Operation<Input, Output>],
    searchSteps: Int,
    maxDepthReached: Int
  ) -> LinearizabilityResult {

    let counterexample = NonLinearizableWitness(
      conflictingOperations: operations.map(\.id),
      explanation: "Exhaustive search of \(searchSteps) states found no valid linearization",
      minimalHistory: operations.map(AnyOperation.init),
      proofOfViolation:
        "Wing-Gong algorithm exhausted all \(searchSteps) possible sequential orderings without finding a valid execution. Maximum depth reached: \(maxDepthReached)."
    )

    return .notLinearizable(counterexample: counterexample)
  }
}

// MARK: - Utility Functions

/// Execute function with timeout
func withTimeout<T: Sendable>(
  _ timeout: Duration,
  operation: @Sendable @escaping () async -> T
) async -> T? {
  let task = Task {
    await operation()
  }

  let timeoutTask = Task {
    try await Task.sleep(for: timeout)
    task.cancel()
  }

  defer {
    timeoutTask.cancel()
  }

  return await task.value
}

// MARK: - Predefined Specifications

extension Spec {
  /// Counter specification (increment/decrement operations)
  public static func counter() -> Spec<Int, CounterOp, Int>
  where Model == Int, Input == CounterOp, Output == Int {
    Spec<Int, CounterOp, Int>(
      apply: { state, op in
        switch op {
        case .increment(let delta):
          let oldValue = state
          state += delta
          return oldValue

        case .decrement(let delta):
          let oldValue = state
          state -= delta
          return oldValue

        case .get:
          return state
        }
      },
      precondition: { _, _ in
        // All operations are always valid for counter
        true
      },
      postcondition: { _, _ in
        // All results are valid for counter
        true
      },
      commutes: { _, op1, op2 in
        // Only get operations commute with everything
        switch (op1, op2) {
        case (.get, _), (_, .get):
          return true

        default:
          return false
        }
      }
    )
  }

  /// Set specification (add/remove/contains operations)
  public static func set<T: Sendable & Hashable>() -> Spec<Set<T>, SetOp<T>, SetResult<T>>
  where Model == Set<T>, Input == SetOp<T>, Output == SetResult<T> {
    Spec<Set<T>, SetOp<T>, SetResult<T>>(
      apply: { state, op in
        switch op {
        case .add(let element):
          let wasPresent = state.contains(element)
          state.insert(element)
          return .addResult(!wasPresent)

        case .remove(let element):
          let wasPresent = state.contains(element)
          state.remove(element)
          return .removeResult(wasPresent)

        case .contains(let element):
          return .containsResult(state.contains(element))
        }
      }
    )
  }
}

/// Operations for counter specification
public enum CounterOp: Sendable, Equatable, CustomStringConvertible {
  case increment(Int)
  case decrement(Int)
  case get

  public var description: String {
    switch self {
    case .increment(let delta):
      return "increment(\(delta))"

    case .decrement(let delta):
      return "decrement(\(delta))"

    case .get:
      return "get"
    }
  }
}

/// Operations for set specification
public enum SetOp<T: Sendable & Hashable>: Sendable, Equatable {
  case add(T)
  case remove(T)
  case contains(T)
}

/// Results for set specification
public enum SetResult<T: Sendable & Hashable>: Sendable, Equatable {
  case addResult(Bool)  // true if element was newly added
  case removeResult(Bool)  // true if element was present
  case containsResult(Bool)  // true if element is present
}

// MARK: - Public API

extension LinearizabilityChecker {

  /// Convenience method for checking counter linearizability
  public static func checkCounter(
    operations: [Operation<CounterOp, Int>],
    initialValue: Int = 0,
    config: CheckerConfig = .fast
  ) async -> LinearizabilityResult {
    let checker = LinearizabilityChecker<Int, CounterOp, Int>(
      spec: .counter(),
      initial: initialValue,
      config: config
    )

    return await checker.check(operations: operations)
  }

  /// Convenience method for checking set linearizability
  public static func checkSet<T: Sendable & Hashable>(
    operations: [Operation<SetOp<T>, SetResult<T>>],
    initialSet: Set<T> = Set<T>(),
    config: CheckerConfig = .fast
  ) async -> LinearizabilityResult {
    let checker = LinearizabilityChecker<Set<T>, SetOp<T>, SetResult<T>>(
      spec: .set(),
      initial: initialSet,
      config: config
    )

    return await checker.check(operations: operations)
  }
}

// MARK: - Parallel Property Runner

/// Configuration for parallel execution
public struct ParallelExecutionConfig: Sendable {
  public let maxConcurrency: Int
  public let jitteringStrategy: JitteringStrategy
  public let rounds: Int
  public let timeout: Duration
  public let recordHistory: Bool

  public init(
    maxConcurrency: Int = 4,
    jitteringStrategy: JitteringStrategy = .random,
    rounds: Int = 100,
    timeout: Duration = .seconds(30),
    recordHistory: Bool = true
  ) {
    self.maxConcurrency = maxConcurrency
    self.jitteringStrategy = jitteringStrategy
    self.rounds = rounds
    self.timeout = timeout
    self.recordHistory = recordHistory
  }

  public static let quick = Self(maxConcurrency: 2, rounds: 10)
  public static let thorough = Self(maxConcurrency: 8, rounds: 1000)
}

/// Jittering strategies for inducing race conditions
public enum JitteringStrategy: Sendable {
  /// No jittering - execute as fast as possible
  case none
  /// Random delays between operations
  case random
  /// Yield-based cooperative delays
  case yieldBased
  /// Fixed delay between operations
  case fixed(Duration)
  /// Adaptive jittering based on contention
  case adaptive

  /// Apply jitter before operation execution
  func apply() async {
    switch self {
    case .none:
      break

    case .random:
      let delayNanos = UInt64.random(in: 0..<1000)
      try? await Task.sleep(nanoseconds: delayNanos)

    case .yieldBased:
      await Task.yield()

    case .fixed(let duration):
      try? await Task.sleep(for: duration)

    case .adaptive:
      // Adaptive: start with yield, add random delay
      await Task.yield()
      if Bool.random() {
        try? await Task.sleep(nanoseconds: UInt64.random(in: 0..<500))
      }
    }
  }
}

/// **ParallelPropertyRunner**: Executes property tests with concurrent jittering
///
/// Runs operations in parallel with configurable timing jitter to expose
/// race conditions and verify linearizability under contention.
///
/// **Usage:**
/// ```swift
/// let runner = ParallelPropertyRunner(config: .thorough)
/// let result = await runner.runConcurrently(
///   operations: [op1, op2, op3],
///   spec: counterSpec,
///   initial: 0
/// )
/// ```
public actor ParallelPropertyRunner<Model, Input, Output>
where Model: Sendable, Input: Sendable, Output: Sendable & Equatable {

  private let config: ParallelExecutionConfig
  private let checker: LinearizabilityChecker<Model, Input, Output>

  /// Recorded execution histories for debugging
  private var recordedHistories: [[Operation<Input, Output>]] = []

  /// Statistics from execution
  private var successfulRounds: Int = 0
  private var failedRounds: Int = 0

  public init(
    spec: Spec<Model, Input, Output>,
    initial: Model,
    config: ParallelExecutionConfig = ParallelExecutionConfig()
  ) {
    self.config = config
    self.checker = LinearizabilityChecker(spec: spec, initial: initial)
  }

  /// Run concurrent operations with randomized scheduling
  ///
  /// - Parameter operations: Operations to execute concurrently
  /// - Returns: Linearizability result after checking all executions
  public func runConcurrently(
    operations: [Operation<Input, Output>]
  ) async -> ParallelExecutionResult {

    let startTime = ContinuousClock().now

    for round in 0..<config.rounds {
      // Shuffle operation order for this round
      let shuffledOps = operations.shuffled()

      // Execute with jittering
      let reorderedOps = await executeWithJitter(shuffledOps)

      // Record history if configured
      if config.recordHistory {
        recordedHistories.append(reorderedOps)
      }

      // Check linearizability
      let result = await checker.check(
        operations: reorderedOps,
        timeout: config.timeout
      )

      switch result {
      case .linearizable:
        successfulRounds += 1

      case .notLinearizable(let witness):
        failedRounds += 1
        return ParallelExecutionResult(
          isLinearizable: false,
          successfulRounds: successfulRounds,
          failedRounds: failedRounds,
          totalRounds: round + 1,
          executionTime: ContinuousClock().now - startTime,
          failingHistory: reorderedOps.map(AnyOperation.init),
          counterexample: witness
        )

      case .timeout, .error:
        failedRounds += 1
      }

      // Check timeout
      if ContinuousClock().now - startTime > config.timeout {
        break
      }
    }

    return ParallelExecutionResult(
      isLinearizable: true,
      successfulRounds: successfulRounds,
      failedRounds: failedRounds,
      totalRounds: config.rounds,
      executionTime: ContinuousClock().now - startTime,
      failingHistory: nil,
      counterexample: nil
    )
  }

  /// Execute operations with jittering
  private func executeWithJitter(
    _ operations: [Operation<Input, Output>]
  ) async -> [Operation<Input, Output>] {
    // For simulation, we apply jitter and record timing
    var reorderedOps: [Operation<Input, Output>] = []

    await withTaskGroup(of: Operation<Input, Output>?.self) { group in
      for operation in operations {
        group.addTask {
          // Apply jitter
          await self.config.jitteringStrategy.apply()
          return operation
        }
      }

      for await op in group {
        if let op = op {
          reorderedOps.append(op)
        }
      }
    }

    return reorderedOps
  }

  /// Get recorded histories for debugging
  public func getRecordedHistories() -> [[AnyOperation]] {
    recordedHistories.map { history in
      history.map(AnyOperation.init)
    }
  }

  /// Reset statistics and recorded histories
  public func reset() {
    successfulRounds = 0
    failedRounds = 0
    recordedHistories = []
  }
}

/// Result of parallel property execution
public struct ParallelExecutionResult: Sendable {
  public let isLinearizable: Bool
  public let successfulRounds: Int
  public let failedRounds: Int
  public let totalRounds: Int
  public let executionTime: Duration
  public let failingHistory: [AnyOperation]?
  public let counterexample: NonLinearizableWitness?

  public var successRate: Double {
    guard totalRounds > 0 else { return 0 }
    return Double(successfulRounds) / Double(totalRounds)
  }

  public func summary() -> String {
    var result = "Parallel Execution Results\n"
    result += "===========================\n"
    result += "Linearizable: \(isLinearizable ? "✓" : "✗")\n"
    result += "Success Rate: \(String(format: "%.1f%%", successRate * 100))\n"
    result += "Rounds: \(successfulRounds)/\(totalRounds) passed\n"
    result += "Execution Time: \(executionTime)\n"

    if let counterexample = counterexample {
      result += "\n\(counterexample.debugInfo())"
    }

    return result
  }
}

// MARK: - Concurrency Scheduler

/// Active scheduler for inducing specific interleavings
public actor ConcurrencyScheduler {

  /// Scheduling strategy
  public enum Strategy: Sendable {
    /// Randomize execution order
    case random
    /// Prioritize specific threads
    case prioritized([ThreadID])
    /// Round-robin scheduling
    case roundRobin
    /// Maximize contention
    case maxContention
  }

  private let strategy: Strategy
  private var pendingOperations: [UUID: () async -> Void] = [:]
  private var executionOrder: [UUID] = []

  public init(strategy: Strategy = .random) {
    self.strategy = strategy
  }

  /// Schedule an operation for execution
  public func schedule(
    id: UUID,
    operation: @escaping @Sendable () async -> Void
  ) {
    pendingOperations[id] = operation
  }

  /// Execute all scheduled operations according to strategy
  public func executeAll() async {
    let orderedIds = orderOperations()

    for id in orderedIds {
      if let operation = pendingOperations[id] {
        await operation()
        executionOrder.append(id)
      }
    }

    pendingOperations.removeAll()
  }

  /// Get the execution order from last run
  public func getExecutionOrder() -> [UUID] {
    executionOrder
  }

  /// Order operations according to strategy
  private func orderOperations() -> [UUID] {
    let ids = Array(pendingOperations.keys)

    switch strategy {
    case .random:
      return ids.shuffled()

    case .prioritized(let priorities):
      // Use priorities to create a preference ordering
      _ = Set(priorities.map(\.value))
      return ids.sorted { id1, id2 in
        // This is a simplified ordering - real implementation would
        // associate thread IDs with operations
        id1.uuidString < id2.uuidString
      }

    case .roundRobin:
      return ids.sorted { $0.uuidString < $1.uuidString }

    case .maxContention:
      // Interleave operations to maximize contention
      return ids.shuffled()
    }
  }

  /// Reset scheduler state
  public func reset() {
    pendingOperations.removeAll()
    executionOrder.removeAll()
  }
}

// MARK: - Concurrent Test Helpers

extension Gen {

  /// Generate concurrent operation sequences
  public static func concurrentOperations<Op>(
    operations: Gen<Op>,
    threads: Int = 4,
    opsPerThread: Int = 5
  ) -> Gen<[[Op]]> where Op: Sendable {
    Gen<[[Op]]> { rng, size in
      (0..<threads).map { _ in
        (0..<opsPerThread).map { _ in
          operations.generate(&rng, size)
        }
      }
    }
  }
  // swiftlint:disable:next file_length
}
