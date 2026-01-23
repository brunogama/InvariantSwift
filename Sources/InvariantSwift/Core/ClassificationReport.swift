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
  /// Produces QuickCheck-style output:
  /// ```
  /// +++ OK, passed 100 tests.
  ///
  /// Labels (100 iterations):
  ///   sign:
  ///     48.0% positive
  ///     45.0% negative
  ///      7.0% zero
  ///
  /// Coverage:
  ///   ✓ extremes: 12.5% (required ≥10.0%)
  ///   ✗ boundaries: 3.2% (required ≥5.0%) FAILED
  /// ```
  ///
  /// - Returns: Formatted report string
  public func format() -> String {
    // Empty report - silent
    if labelDistribution.isEmpty && coverageResults.isEmpty {
      return ""
    }

    var lines: [String] = []

    // Label distributions (sorted by percentage, highest first)
    if !labelDistribution.isEmpty {
      lines.append("")
      lines.append("Labels (\(totalIterations) iterations):")

      for category in labelDistribution.keys.sorted() {
        lines.append("  \(category):")
        if let categoryLabels = labelDistribution[category] {
          // Sort by percentage descending (highest first), then by name
          let sortedLabels = categoryLabels.sorted { first, second in
            if first.value.percentage != second.value.percentage {
              return first.value.percentage > second.value.percentage
            }
            return first.key < second.key
          }

          // Calculate padding for percentage alignment
          for (label, stats) in sortedLabels {
            let percentStr = String(format: "%5.1f", stats.percentage)
            lines.append("    \(percentStr)% \(label)")
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
          let status = result.met ? "" : " FAILED"
          lines.append("  \(icon) \(name): \(percentStr)% (required ≥\(thresholdStr)%)\(status)")
        }
      }
    }

    return lines.joined(separator: "\n")
  }

  /// Formats the report for inclusion in failure messages.
  ///
  /// More verbose than `format()`, includes suggestions for fixing.
  ///
  /// - Returns: Verbose formatted report with actionable guidance
  public func formatForFailure() -> String {
    var lines: [String] = []

    lines.append("Classification Report:")
    lines.append("─────────────────────────────────────────")

    // Include standard format
    let standardFormat = format()
    if !standardFormat.isEmpty {
      lines.append(standardFormat)
    }

    // Add suggestions for unmet coverage
    let unmet = unmetCoverageChecks
    if !unmet.isEmpty {
      lines.append("")
      lines.append("Suggestions:")
      for name in unmet {
        if let result = coverageResults[name] {
          let gap = result.threshold - result.percentage
          lines.append("  - \(name): Need \(String(format: "%.1f", gap))% more coverage")
          lines.append("    Try adjusting the generator to produce more matching values,")
          lines.append("    or reduce the coverage threshold if too strict.")
        }
      }
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
