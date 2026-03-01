/// Linearizability model types: operations, specs, search state, and witnesses.
///
/// Core data types for the Wing-Gong linearizability checking algorithm.
/// Extracted from Linearizability.swift to keep the checker file under budget.

import Foundation
import InvariantSwiftCore

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
