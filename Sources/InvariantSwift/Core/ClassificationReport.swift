import Foundation

// MARK: - Classification Report

/// Statistics from classification during a property test run.
///
/// `ClassificationReport` provides a structured view of input space coverage,
/// showing the distribution of labels across categories and whether coverage
/// thresholds were met.
///
/// - Example Output:
///   ```
///   Classification:
///     sign:
///       positive: 45 (45.0%)
///       negative: 42 (42.0%)
///       zero:     13 (13.0%)
///
///   Coverage:
///     ✓ boundaries: 12.5% (threshold: 10.0%)
///     ✗ extremes: 3.2% (threshold: 5.0%)
///   ```
///
/// - See Also: ``ClassificationContext``, ``ClassifyingProperty``
public struct ClassificationReport: Sendable, Codable, Equatable {

  // MARK: - Nested Types

  /// Statistics for a single classification label.
  public struct LabelStats: Sendable, Codable, Equatable {
    /// Number of times this label was applied
    public let count: Int

    /// Percentage of iterations with this label (within category)
    public let percentage: Double

    public init(count: Int, percentage: Double) {
      self.count = count
      self.percentage = percentage
    }
  }

  /// Result of a coverage check.
  public struct CoverageResult: Sendable, Codable, Equatable {
    /// Name of the coverage check
    public let name: String

    /// Number of times the condition was true
    public let hits: Int

    /// Total number of times the condition was checked
    public let checks: Int

    /// Actual coverage percentage achieved
    public let percentage: Double

    /// Required minimum percentage
    public let threshold: Double

    /// Whether the threshold was met
    public let met: Bool

    public init(
      name: String,
      hits: Int,
      checks: Int,
      percentage: Double,
      threshold: Double,
      met: Bool
    ) {
      self.name = name
      self.hits = hits
      self.checks = checks
      self.percentage = percentage
      self.threshold = threshold
      self.met = met
    }
  }

  // MARK: - Properties

  /// Distribution of labels per category.
  ///
  /// Outer key is category name, inner key is label name.
  public let labelDistribution: [String: [String: LabelStats]]

  /// Results of coverage checks.
  ///
  /// Key is the coverage check name.
  public let coverageResults: [String: CoverageResult]

  /// Total iterations observed during the test run.
  public let totalIterations: Int

  // MARK: - Initialization

  public init(
    labelDistribution: [String: [String: LabelStats]],
    coverageResults: [String: CoverageResult],
    totalIterations: Int
  ) {
    self.labelDistribution = labelDistribution
    self.coverageResults = coverageResults
    self.totalIterations = totalIterations
  }

  /// Creates an empty report.
  public static var empty: Self {
    Self(labelDistribution: [:], coverageResults: [:], totalIterations: 0)
  }

  // MARK: - Computed Properties

  /// Whether all coverage thresholds were met.
  public var allCoverageThresholdsMet: Bool {
    coverageResults.values.allSatisfy(\.met)
  }

  /// Names of coverage checks that did not meet their thresholds.
  public var unmetCoverageChecks: [String] {
    coverageResults.values.filter { !$0.met }.map(\.name).sorted()
  }

  // MARK: - Formatting

  /// Formats the report for human-readable output.
  ///
  /// Produces a multi-line report with:
  /// - Classification distribution tables per category
  /// - Coverage check results with pass/fail indicators
  ///
  /// - Returns: Formatted report string
  public func format() -> String {
    var lines: [String] = []

    // Header
    if !labelDistribution.isEmpty || !coverageResults.isEmpty {
      lines.append("")
      lines.append("Classification Report (\(totalIterations) iterations):")
      lines.append("─────────────────────────────────────────")
    }

    // Label distributions (sorted for determinism)
    if !labelDistribution.isEmpty {
      lines.append("")
      lines.append("Labels:")

      for category in labelDistribution.keys.sorted() {
        lines.append("  \(category):")
        if let categoryLabels = labelDistribution[category] {
          // Sort by count descending, then by name
          let sortedLabels = categoryLabels.sorted { first, second in
            if first.value.count != second.value.count {
              return first.value.count > second.value.count
            }
            return first.key < second.key
          }

          // Calculate padding for alignment
          let maxLabelLength = sortedLabels.map(\.key.count).max() ?? 0

          for (label, stats) in sortedLabels {
            let paddedLabel = label.padding(toLength: maxLabelLength, withPad: " ", startingAt: 0)
            let percentStr = String(format: "%.1f", stats.percentage)
            lines.append("    \(paddedLabel): \(stats.count) (\(percentStr)%)")
          }
        }
      }
    }

    // Coverage results (sorted for determinism)
    if !coverageResults.isEmpty {
      lines.append("")
      lines.append("Coverage:")

      for name in coverageResults.keys.sorted() {
        if let result = coverageResults[name] {
          let icon = result.met ? "✓" : "✗"
          let percentStr = String(format: "%.1f", result.percentage)
          let thresholdStr = String(format: "%.1f", result.threshold)
          lines.append("  \(icon) \(name): \(percentStr)% (threshold: \(thresholdStr)%)")
        }
      }
    }

    if lines.isEmpty {
      return "  (no classifications recorded)"
    }

    return lines.joined(separator: "\n")
  }

  /// Returns a compact single-line summary.
  public var summary: String {
    let labelCount = labelDistribution.values.reduce(0) { $0 + $1.count }
    let coverageCount = coverageResults.count
    let unmetCount = unmetCoverageChecks.count

    var parts: [String] = []
    if labelCount > 0 {
      parts.append("\(labelCount) labels")
    }
    if coverageCount > 0 {
      let status = unmetCount == 0 ? "all met" : "\(unmetCount) unmet"
      parts.append("\(coverageCount) coverage checks (\(status))")
    }

    return parts.isEmpty ? "no classifications" : parts.joined(separator: ", ")
  }
}
