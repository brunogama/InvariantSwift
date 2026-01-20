// MARK: - ISP-0008: Target Collector
// Thread-safe collection of target values during test execution.

import Foundation

// MARK: - Target Collector

/// Collects target values during a single test execution
public final class TargetCollector: @unchecked Sendable {
  private var _targets: [TargetRecord] = []
  private let lock = NSLock()

  /// All recorded targets
  public var targets: [TargetRecord] {
    lock.lock()
    defer { lock.unlock() }
    return _targets
  }

  public init() {}

  /// Record a target value to maximize
  public func record<T: BinaryInteger>(_ value: T, label: String? = nil) {
    let doubleValue = Double(value)
    lock.lock()
    _targets.append(TargetRecord(value: doubleValue, label: label, goal: nil))
    lock.unlock()
  }

  /// Record a floating-point target value to maximize
  public func record<T: BinaryFloatingPoint>(_ value: T, label: String? = nil) {
    let doubleValue = Double(value)
    lock.lock()
    _targets.append(TargetRecord(value: doubleValue, label: label, goal: nil))
    lock.unlock()
  }

  /// Record an integer target value with a goal (minimizing distance)
  public func record<T: BinaryInteger>(_ value: T, toward goal: T, label: String? = nil) {
    let doubleValue = Double(value)
    let doubleGoal = Double(goal)
    lock.lock()
    _targets.append(TargetRecord(value: doubleValue, label: label, goal: doubleGoal))
    lock.unlock()
  }

  /// Record a floating-point target value with a goal (minimizing distance)
  public func record<T: BinaryFloatingPoint>(_ value: T, toward goal: T, label: String? = nil) {
    let doubleValue = Double(value)
    let doubleGoal = Double(goal)
    lock.lock()
    _targets.append(TargetRecord(value: doubleValue, label: label, goal: doubleGoal))
    lock.unlock()
  }

  /// Clear all recorded targets (for reuse)
  public func clear() {
    lock.lock()
    _targets.removeAll()
    lock.unlock()
  }

  /// Compute aggregate score from all targets
  public func computeScore() -> Double {
    lock.lock()
    defer { lock.unlock() }
    return _targets.map(\.score).reduce(0, +)
  }
}

// MARK: - Target History

/// Tracks target values across multiple iterations
public final class TargetHistory: @unchecked Sendable {
  private var history: [String: [(value: Double, iteration: Int)]] = [:]
  private let lock = NSLock()

  public init() {}

  /// Record targets from a single iteration
  public func record(_ targets: [TargetRecord], iteration: Int) {
    lock.lock()
    defer { lock.unlock() }

    for target in targets {
      let label = target.label ?? "unlabeled"
      history[label, default: []].append((target.value, iteration))
    }
  }

  /// Get best value for a label
  public func best(for label: String) -> Double? {
    lock.lock()
    defer { lock.unlock() }
    return history[label]?.map(\.value).max()
  }

  /// Compute statistics for all labels
  public func computeStatistics() -> TargetStatistics {
    lock.lock()
    defer { lock.unlock() }

    let stats =
      history
      .map { label, values in
        let sortedValues = values.map(\.value).sorted()
        guard let maxEntry = values.max(by: { $0.value < $1.value }) else {
          return TargetStatistics.LabelStats(
            label: label,
            min: 0,
            max: 0,
            median: 0,
            count: 0,
            bestIteration: 0
          )
        }

        return TargetStatistics.LabelStats(
          label: label,
          min: sortedValues.first ?? 0,
          max: sortedValues.last ?? 0,
          median: sortedValues.isEmpty ? 0 : sortedValues[sortedValues.count / 2],
          count: values.count,
          bestIteration: maxEntry.iteration
        )
      }
      .sorted { $0.label < $1.label }

    return TargetStatistics(labelStats: stats)
  }
}

// MARK: - Target Statistics

/// Statistics about targets collected during a test run
public struct TargetStatistics: Sendable, CustomStringConvertible {
  /// Statistics for a single target label
  public struct LabelStats: Sendable {
    public let label: String
    public let min: Double
    public let max: Double
    public let median: Double
    public let count: Int
    public let bestIteration: Int

    public var description: String {
      """
      \(label):
          min: \(String(format: "%.2f", min)), max: \(String(format: "%.2f", max)), \
      median: \(String(format: "%.2f", median))
          Found best value \(String(format: "%.2f", max)) at iteration \(bestIteration)
      """
    }
  }

  public let labelStats: [LabelStats]

  public var description: String {
    if labelStats.isEmpty {
      return "No targets recorded"
    }
    return
      "Target Statistics:\n"
      + labelStats.map { "  " + $0.description }.joined(separator: "\n\n")
  }
}
