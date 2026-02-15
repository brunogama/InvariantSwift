import Foundation

// MARK: - ShrinkMetrics

/// Captures metrics about the shrinking process for a property test failure.
///
/// `ShrinkMetrics` records the journey from the original failing counterexample
/// to the minimal shrunken version, providing developers with insight into:
/// - How much the test case was reduced (reduction percentage)
/// - How long shrinking took
/// - How many shrink attempts were made
/// - How many successful reductions occurred
///
/// These metrics help developers understand the shrinking algorithm's effectiveness
/// and build confidence in the minimal counterexample.
///
/// - Example:
///   ```swift
///   let metrics = ShrinkMetrics(
///     attempts: 15,
///     successful: 8,
///     duration: 0.123,
///     originalSize: 100,
///     shrunkSize: 20
///   )
///   // reductionPercentage is automatically computed: 80.0%
///   ```
///
/// - See Also: ``FailureReport``, ``PropertyRunner``
public struct ShrinkMetrics: Sendable {
  /// Total number of shrink attempts made.
  public let attempts: Int

  /// Number of successful reductions that produced smaller failing cases.
  public let successful: Int

  /// Total time spent shrinking (in seconds).
  public let duration: TimeInterval

  /// Percentage reduction from original to shrunk size (0.0-100.0).
  public let reductionPercentage: Double

  /// Description of the shrinking algorithm used.
  public let strategy: String

  /// Creates shrink metrics with all properties.
  ///
  /// - Parameters:
  ///   - attempts: Total shrink attempts made
  ///   - successful: Successful reductions producing smaller failing cases
  ///   - duration: Time spent shrinking in seconds
  ///   - reductionPercentage: Size reduction percentage (0-100)
  ///   - strategy: Shrinking algorithm description (default: "BFS tree search")
  public init(
    attempts: Int,
    successful: Int,
    duration: TimeInterval,
    reductionPercentage: Double,
    strategy: String = "BFS tree search"
  ) {
    self.attempts = attempts
    self.successful = successful
    self.duration = duration
    self.reductionPercentage = reductionPercentage
    self.strategy = strategy
  }

  /// Creates shrink metrics with automatic reduction percentage calculation.
  ///
  /// Computes `reductionPercentage` from original and shrunk sizes:
  /// `((originalSize - shrunkSize) / originalSize) * 100`
  ///
  /// - Parameters:
  ///   - attempts: Total shrink attempts made
  ///   - successful: Successful reductions producing smaller failing cases
  ///   - duration: Time spent shrinking in seconds
  ///   - originalSize: Size of original failing counterexample
  ///   - shrunkSize: Size of minimal counterexample after shrinking
  ///   - strategy: Shrinking algorithm description (default: "BFS tree search")
  public init(
    attempts: Int,
    successful: Int,
    duration: TimeInterval,
    originalSize: Int,
    shrunkSize: Int,
    strategy: String = "BFS tree search"
  ) {
    self.attempts = attempts
    self.successful = successful
    self.duration = duration
    self.strategy = strategy

    // Calculate reduction percentage, guarding against division by zero
    if originalSize > 0 {
      let reduction = Double(originalSize - shrunkSize) / Double(originalSize) * 100.0
      self.reductionPercentage = max(0.0, min(100.0, reduction))
    } else {
      self.reductionPercentage = 0.0
    }
  }
}

// MARK: - Formatting

extension ShrinkMetrics {
  /// Formats metrics as a box-drawn section for failure output.
  ///
  /// Returns a formatted string using box-drawing characters:
  /// ```
  /// ╠══════════════════════════════════════════════════════════════════════════════╣
  /// ║ SHRINKING METRICS:
  /// ║   Reduction:     80.0%
  /// ║   Time:          0.123s
  /// ║   Attempts:      15
  /// ║   Successful:    8
  /// ║   Strategy:      BFS tree search
  /// ```
  ///
  /// - Returns: Formatted metrics section
  public func formatAsBoxSection() -> String {
    var lines: [String] = []

    lines.append("╠══════════════════════════════════════════════════════════════════════════════╣")
    lines.append("║ SHRINKING METRICS:")
    lines.append("║   Reduction:     \(String(format: "%.1f", reductionPercentage))%")
    lines.append("║   Time:          \(String(format: "%.3f", duration))s")
    lines.append("║   Attempts:      \(attempts)")
    lines.append("║   Successful:    \(successful)")
    lines.append("║   Strategy:      \(strategy)")

    return lines.joined(separator: "\n")
  }
}
