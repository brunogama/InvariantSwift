// ShrinkingTrace.swift
// InvariantSwift
//
// Visualization of shrinking steps for debugging property test failures.
// Implements Task 1.12 from the roadmap.

import Foundation

// MARK: - Shrinking Step

/// Represents a single step in the shrinking process.
///
/// Each step captures the value at that point in shrinking and metadata
/// about the shrink operation.
public struct ShrinkStep<T>: Sendable where T: Sendable {
  /// The value at this step.
  public let value: T

  /// The depth in the shrinking tree (0 = original).
  public let depth: Int

  /// Whether this step passed the property predicate.
  public let passed: Bool

  /// Time taken for this shrink attempt (in seconds).
  public let duration: TimeInterval

  /// Optional description of the shrink strategy used.
  public let strategy: String?

  /// Creates a new shrink step.
  public init(
    value: T,
    depth: Int,
    passed: Bool,
    duration: TimeInterval = 0,
    strategy: String? = nil
  ) {
    self.value = value
    self.depth = depth
    self.passed = passed
    self.duration = duration
    self.strategy = strategy
  }
}

// MARK: - Shrinking Trace

// swiftlint:disable:next orphaned_doc_comment
/// Records the complete history of a shrinking operation.
///
/// `ShrinkingTrace` captures every step of the shrinking process, from the
/// original failing value to the minimal counterexample. This is invaluable
/// for understanding and debugging property test failures.
///
/// ## Example Usage
///
/// ```swift
/// let trace = ShrinkingTrace<[Int]>(original: [1, 2, 3, 4, 5])
/// trace.record(value: [1, 2, 3, 4], passed: false, depth: 1)
/// trace.record(value: [1, 2, 3], passed: false, depth: 2)
/// trace.record(value: [1, 3], passed: false, depth: 3)
/// trace.record(value: [1], passed: false, depth: 4)
/// trace.record(value: [], passed: true, depth: 5)  // Passes, so [1] is minimal
/// trace.complete(minimal: [1])
///
// swiftlint:disable:next no_print
/// print(trace.formattedOutput())
/// // Original: [1, 2, 3, 4, 5]
/// // Step 1 (depth 1): [1, 2, 3, 4] ✗
/// // Step 2 (depth 2): [1, 2, 3] ✗
/// // Step 3 (depth 3): [1, 3] ✗
/// // Step 4 (depth 4): [1] ✗
/// // Step 5 (depth 5): [] ✓
/// // Minimal counterexample: [1]
/// ```
///
/// - See Also: ``PropertyRunner``, ``ShrinkStep``
public final class ShrinkingTrace<T>: @unchecked Sendable where T: Sendable {

  // MARK: - Properties

  /// The original failing value.
  public let original: T

  /// All recorded shrinking steps.
  public private(set) var steps: [ShrinkStep<T>] = []

  /// The minimal counterexample (if shrinking completed).
  public private(set) var minimal: T?

  /// Total shrinking time.
  public private(set) var totalDuration: TimeInterval = 0

  /// Number of successful shrinks (steps that still failed the property).
  public var successfulShrinks: Int {
    steps.filter { !$0.passed }.count
  }

  /// Number of attempted shrinks.
  public var totalAttempts: Int {
    steps.count
  }

  /// Maximum depth reached during shrinking.
  public var maxDepth: Int {
    steps.map(\.depth).max() ?? 0
  }

  /// Lock for thread-safe access.
  private let lock = NSLock()

  // MARK: - Initialization

  /// Creates a new shrinking trace.
  ///
  /// - Parameter original: The original failing value.
  public init(original: T) {
    self.original = original
  }

  // MARK: - Recording

  /// Records a shrinking step.
  ///
  /// - Parameters:
  ///   - value: The value tested at this step.
  ///   - passed: Whether the property passed (true) or failed (false).
  ///   - depth: The depth in the shrinking tree.
  ///   - duration: Time taken for this step.
  ///   - strategy: Optional description of the shrink strategy.
  public func record(
    value: T,
    passed: Bool,
    depth: Int,
    duration: TimeInterval = 0,
    strategy: String? = nil
  ) {
    lock.lock()
    defer { lock.unlock() }

    steps.append(
      ShrinkStep(
        value: value,
        depth: depth,
        passed: passed,
        duration: duration,
        strategy: strategy
      )
    )
    totalDuration += duration
  }

  /// Marks the shrinking as complete with the minimal counterexample.
  ///
  /// - Parameter minimal: The minimal counterexample found.
  public func complete(minimal: T) {
    lock.lock()
    defer { lock.unlock() }
    self.minimal = minimal
  }

  // MARK: - Output Formatting

  /// Generates a formatted text representation of the trace.
  ///
  /// - Parameter valueFormatter: Optional custom formatter for values.
  /// - Returns: Multi-line string showing the shrinking history.
  public func formattedOutput(
    valueFormatter: ((T) -> String)? = nil
  ) -> String {
    let format = valueFormatter ?? { String(describing: $0) }

    var lines: [String] = []

    lines.append("╔══════════════════════════════════════════════════════════════╗")
    lines.append("║                     SHRINKING TRACE                          ║")
    lines.append("╠══════════════════════════════════════════════════════════════╣")
    lines.append("║ Original: \(format(original))")
    lines.append("╠══════════════════════════════════════════════════════════════╣")

    for (index, step) in steps.enumerated() {
      let status = step.passed ? "✓ (passed)" : "✗ (failed)"
      let depthStr = String(repeating: "  ", count: min(step.depth, 5))
      let strategyStr = step.strategy.map { " [\($0)]" } ?? ""

      lines.append(
        "║ \(depthStr)Step \(index + 1) (d=\(step.depth)): \(format(step.value)) \(status)\(strategyStr)"
      )
    }

    lines.append("╠══════════════════════════════════════════════════════════════╣")

    if let minimal = minimal {
      lines.append("║ Minimal counterexample: \(format(minimal))")
    }

    lines.append("╠══════════════════════════════════════════════════════════════╣")
    lines.append("║ Statistics:")
    lines.append("║   Total attempts: \(totalAttempts)")
    lines.append("║   Successful shrinks: \(successfulShrinks)")
    lines.append("║   Max depth: \(maxDepth)")
    lines.append("║   Total time: \(String(format: "%.3f", totalDuration))s")
    lines.append("╚══════════════════════════════════════════════════════════════╝")

    return lines.joined(separator: "\n")
  }

  /// Generates a condensed one-line summary.
  public func condensedSummary(
    valueFormatter: ((T) -> String)? = nil
  ) -> String {
    let format = valueFormatter ?? { String(describing: $0) }
    let minStr = minimal.map { format($0) } ?? "?"

    return
      "\(format(original)) → \(minStr) (\(successfulShrinks) shrinks, \(String(format: "%.3f", totalDuration))s)"
  }

  /// Generates a JSON representation of the trace.
  ///
  /// - Parameter valueFormatter: Optional custom formatter for values.
  /// - Returns: JSON string representation.
  public func toJSON(
    valueFormatter: ((T) -> String)? = nil
  ) -> String {
    let format = valueFormatter ?? { String(describing: $0) }

    var json: [String: Any] = [
      "original": format(original),
      "totalAttempts": totalAttempts,
      "successfulShrinks": successfulShrinks,
      "maxDepth": maxDepth,
      "totalDuration": totalDuration,
      "steps": steps.map { step in
        [
          "value": format(step.value),
          "depth": step.depth,
          "passed": step.passed,
          "duration": step.duration,
          "strategy": step.strategy as Any,
        ] as [String: Any]
      },
    ]

    if let minimal = minimal {
      json["minimal"] = format(minimal)
    }

    // Use JSONSerialization for proper escaping
    if let data = try? JSONSerialization.data(
      withJSONObject: json,
      options: [.prettyPrinted, .sortedKeys]
    ),
      let jsonString = String(data: data, encoding: .utf8)
    {
      return jsonString
    }

    // Fallback to manual formatting
    return "{\"error\": \"Failed to serialize trace\"}"
  }
}

// MARK: - Trace Builder

/// A builder for creating shrinking traces with fluent API.
public final class ShrinkingTraceBuilder<T>: @unchecked Sendable where T: Sendable {
  private let trace: ShrinkingTrace<T>
  private var currentDepth: Int = 0
  private let startTime: Date
  private var lastStepTime: Date

  /// Creates a new trace builder.
  ///
  /// - Parameter original: The original failing value.
  public init(original: T) {
    self.trace = ShrinkingTrace(original: original)
    self.startTime = Date()
    self.lastStepTime = startTime
  }

  /// Records a shrink attempt.
  ///
  /// - Parameters:
  ///   - value: The shrunk value.
  ///   - passed: Whether the property passed.
  ///   - strategy: Optional strategy description.
  /// - Returns: Self for chaining.
  @discardableResult
  public func step(
    _ value: T,
    passed: Bool,
    strategy: String? = nil
  ) -> Self {
    if !passed {
      currentDepth += 1
    }

    let now = Date()
    let duration = now.timeIntervalSince(lastStepTime)
    lastStepTime = now

    trace.record(
      value: value,
      passed: passed,
      depth: currentDepth,
      duration: duration,
      strategy: strategy
    )

    return self
  }

  /// Completes the trace and returns it.
  ///
  /// - Parameter minimal: The minimal counterexample.
  /// - Returns: The completed trace.
  public func complete(minimal: T) -> ShrinkingTrace<T> {
    trace.complete(minimal: minimal)
    return trace
  }

  /// Returns the trace without marking it complete.
  public func build() -> ShrinkingTrace<T> {
    trace
  }
}

// MARK: - Convenience Extensions

extension ShrinkingTrace {
  /// Creates a simple trace showing direct shrinking path.
  ///
  /// - Parameters:
  ///   - from: The original value.
  ///   - to: The minimal value.
  ///   - steps: Intermediate values.
  /// - Returns: A completed trace.
  public static func simple(
    from original: T,
    to minimal: T,
    through intermediates: [T] = []
  ) -> ShrinkingTrace<T> {
    let trace = ShrinkingTrace(original: original)

    for (index, value) in intermediates.enumerated() {
      trace.record(value: value, passed: false, depth: index + 1)
    }

    trace.complete(minimal: minimal)
    return trace
  }
}
