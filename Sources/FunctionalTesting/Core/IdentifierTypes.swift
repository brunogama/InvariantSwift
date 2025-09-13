/// IdentifierTypes.swift - Consolidated Identifier System
///
/// Simple, consolidated identifier definitions to eliminate duplication
/// across TaskID, ThreadID, ActorID, StepID, and BranchID.
/// All types maintain the same API as before but are defined in one place.

import Foundation

// MARK: - Type Aliases

/// Type-erased Sendable value for dynamic typing with concurrency safety
/// Used throughout the codebase for storing heterogeneous Sendable values
public typealias AnySendable = any Sendable

// MARK: - Consolidated Identifier Types

/// Task identifier for the DICE scheduler
public struct TaskID: Sendable, Hashable, CustomStringConvertible {
  public let value: UInt64

  public init(_ value: UInt64) {
    self.value = value
  }

  public var description: String {
    "Task(\(value))"
  }

  /// Create a new unique task identifier
  public static func unique() -> Self {
    Self(UInt64.random(in: 0...UInt64.max))
  }
}

/// Thread identifier for linearizability checking
public struct ThreadID: Sendable, Hashable, CustomStringConvertible {
  public let value: UInt64

  public init(_ value: UInt64) {
    self.value = value
  }

  public var description: String {
    "Thread(\(value))"
  }

  /// Create a new unique thread identifier
  public static func unique() -> Self {
    Self(UInt64.random(in: 0...UInt64.max))
  }
}

/// Actor identifier for DICE scheduler
public struct ActorID: Sendable, Hashable, CustomStringConvertible {
  public let value: String

  public init(_ value: String) {
    self.value = value
  }

  public var description: String {
    "Actor(\(value))"
  }

  /// Create an actor identifier from a type name
  public static func from<T>(_ type: T.Type) -> Self {
    Self(String(describing: type))
  }
}

/// Logical timestamp for ordering operations
public typealias LogicalTime = UInt64

/// Step identifier combining task and timestamp
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

  /// Create a step identifier from components
  public static func from(taskId: TaskID, timestamp: LogicalTime) -> Self {
    Self(taskId: taskId, timestamp: timestamp)
  }
}

/// Branch identifier combining function name and index
public struct BranchID: Sendable, Hashable, CustomStringConvertible {
  public let functionName: String
  public let branchIndex: Int

  public init(functionName: String, branchIndex: Int) {
    self.functionName = functionName
    self.branchIndex = branchIndex
  }

  public var description: String {
    "\(functionName):\(branchIndex)"
  }

  /// Create a branch identifier from components
  public static func from(functionName: String, branchIndex: Int) -> Self {
    Self(functionName: functionName, branchIndex: branchIndex)
  }
}
