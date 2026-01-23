import InvariantSwiftCore
// MARK: - ISP-0008: Targeted Property Testing
// Global functions and task-local context for targeted property testing.

import Foundation

// MARK: - Thread-Local Target Collector

/// Namespace for task-local storage
public enum TargetedTestingContext {
  /// Thread-local target collector
  @TaskLocal public static var currentTargetCollector: TargetCollector?
}

/// Global accessor for the current target collector
public func getCurrentTargetCollector() -> TargetCollector? {
  TargetedTestingContext.currentTargetCollector
}

// MARK: - Target Recording Functions

/// Record an integer target value to maximize during testing
/// - Parameters:
///   - value: The value to optimize (higher is better)
///   - label: Optional label to identify this target
public func recordTarget<T: BinaryInteger>(_ value: T, label: String? = nil) {
  TargetedTestingContext.currentTargetCollector?.record(value, label: label)
}

/// Record a floating-point target value to maximize during testing
/// - Parameters:
///   - value: The value to optimize (higher is better)
///   - label: Optional label to identify this target
public func recordTarget<T: BinaryFloatingPoint>(_ value: T, label: String? = nil) {
  TargetedTestingContext.currentTargetCollector?.record(value, label: label)
}

/// Record an integer target value to reach a specific goal
/// - Parameters:
///   - value: The current value
///   - toward: The goal value to approach
///   - label: Optional label to identify this target
public func recordTarget<T: BinaryInteger>(_ value: T, toward goal: T, label: String? = nil) {
  TargetedTestingContext.currentTargetCollector?.record(value, toward: goal, label: label)
}

/// Record a floating-point target value to reach a specific goal
/// - Parameters:
///   - value: The current value
///   - toward: The goal value to approach
///   - label: Optional label to identify this target
public func recordTarget<T: BinaryFloatingPoint>(_ value: T, toward goal: T, label: String? = nil) {
  TargetedTestingContext.currentTargetCollector?.record(value, toward: goal, label: label)
}
