import Foundation

// MARK: - Classification Context

/// Tracks a single coverage check with its threshold.
private struct CoverageCheck: Sendable {
  var hits: Int
  var checks: Int
  var threshold: Double
}

/// Collects classification labels and coverage data during property execution.
///
/// `ClassificationContext` enables inline classification within property bodies,
/// providing feedback on input space distribution. This helps identify when tests
/// only exercise a narrow slice of the input space.
///
/// **Thread Safety:** Uses internal locking for concurrent access during parallel execution.
///
/// - Example:
///   ```swift
///   let property = ClassifyingProperty(generator: Gen.int(in: -100...100)) { n, ctx in
///       ctx.classify("sign", n < 0 ? "negative" : n > 0 ? "positive" : "zero")
///       ctx.cover("extremes", percentage: 5.0) { abs(n) > 90 }
///       return n + 0 == n
///   }
///   ```
///
/// - See Also: ``ClassificationReport``, ``ClassifyingProperty``
public final class ClassificationContext: @unchecked Sendable {

  // MARK: - Properties

  private let lock = NSLock()

  /// Category -> Label -> Count
  private var labels: [String: [String: Int]] = [:]

  /// Coverage check name -> check data
  private var coverageChecks: [String: CoverageCheck] = [:]

  /// Total number of iterations observed
  private var iterationCount: Int = 0

  // MARK: - Initialization

  /// Creates a new empty classification context.
  public init() {}

  // MARK: - Classification API

  /// Classify the current test input with a label under a category.
  ///
  /// Classifications are aggregated across all iterations and reported as
  /// a distribution table when the property test completes.
  ///
  /// - Parameters:
  ///   - category: A grouping name for related labels (e.g., "sign", "size")
  ///   - label: The classification label for this input (e.g., "positive", "small")
  ///
  /// - Example:
  ///   ```swift
  ///   ctx.classify("magnitude", n > 1000 ? "large" : "small")
  ///   ctx.classify("sign", n < 0 ? "negative" : "non-negative")
  ///   ```
  public func classify(_ category: String, _ label: String) {
    lock.lock()
    defer { lock.unlock() }

    labels[category, default: [:]][label, default: 0] += 1
  }

  /// Check and track coverage for a named condition.
  ///
  /// `cover` records whether a condition was met for coverage tracking purposes.
  /// When `enforceCoverageThresholds` is enabled in `PropertyConfig`, the property
  /// will fail if the condition isn't met at least `percentage`% of the time.
  ///
  /// - Parameters:
  ///   - name: Identifier for this coverage check
  ///   - percentage: Required minimum percentage (0-100) of iterations meeting the condition
  ///   - condition: Closure evaluated to determine if condition is met
  ///
  /// - Returns: The result of evaluating the condition (passthrough)
  ///
  /// - Example:
  ///   ```swift
  ///   // Ensure at least 10% of inputs are boundary values
  ///   ctx.cover("boundaries", percentage: 10.0) { n == Int.min || n == Int.max }
  ///   ```
  @discardableResult
  public func cover(_ name: String, percentage threshold: Double, _ condition: () -> Bool) -> Bool {
    let result = condition()

    lock.lock()
    defer { lock.unlock() }

    var check = coverageChecks[name] ?? CoverageCheck(hits: 0, checks: 0, threshold: threshold)
    check.checks += 1
    if result {
      check.hits += 1
    }
    // Use the most restrictive threshold if called multiple times
    check.threshold = max(check.threshold, threshold)
    coverageChecks[name] = check

    return result
  }

  /// Record a label for the current iteration.
  ///
  /// This is a convenience method for unconditional labeling without a category.
  /// Labels are tracked under the "labels" category.
  ///
  /// Use this to attach descriptive labels to test iterations for reporting purposes.
  ///
  /// - Parameter text: The label to attach to this iteration
  ///
  /// - Example:
  ///   ```swift
  ///   ctx.label("edge case: empty array")
  ///   ctx.label("typical input")
  ///   ```
  public func label(_ text: String) {
    classify("labels", text)
  }

  /// Collect a value for histogram tracking.
  ///
  /// Collected values are converted to strings and tracked as labels.
  /// Use bucketing for continuous values to prevent unbounded label sets.
  ///
  /// This is useful for tracking distributions of computed values (e.g., array lengths,
  /// numeric ranges) without manually creating buckets.
  ///
  /// - Parameters:
  ///   - value: The value to collect
  ///   - category: The category name (default: "collected")
  ///
  /// - Example:
  ///   ```swift
  ///   // Track array length distribution
  ///   ctx.collect(array.count, category: "array_length")
  ///
  ///   // Track bucketed numeric ranges
  ///   let bucket = n < 0 ? "negative" : n < 10 ? "small" : n < 100 ? "medium" : "large"
  ///   ctx.collect(bucket, category: "magnitude")
  ///   ```
  public func collect<U: CustomStringConvertible>(_ value: U, category: String = "collected") {
    classify(category, String(describing: value))
  }

  // MARK: - Internal API

  /// Record that an iteration has been observed.
  func recordIteration() {
    lock.lock()
    defer { lock.unlock() }
    iterationCount += 1
  }

  /// Merge another context's data into this one.
  ///
  /// Used for aggregating results from parallel property execution.
  ///
  /// - Parameter other: The context to merge from
  public func merge(_ other: ClassificationContext) {
    lock.lock()
    defer { lock.unlock() }

    other.lock.lock()
    defer { other.lock.unlock() }

    // Merge labels
    for (category, categoryLabels) in other.labels {
      for (label, count) in categoryLabels {
        labels[category, default: [:]][label, default: 0] += count
      }
    }

    // Merge coverage checks
    for (name, otherCheck) in other.coverageChecks {
      if var existing = coverageChecks[name] {
        existing.hits += otherCheck.hits
        existing.checks += otherCheck.checks
        existing.threshold = max(existing.threshold, otherCheck.threshold)
        coverageChecks[name] = existing
      } else {
        coverageChecks[name] = otherCheck
      }
    }

    iterationCount += other.iterationCount
  }

  /// Generate a classification report from the collected data.
  ///
  /// - Returns: A structured report with label distributions and coverage results
  public func report() -> ClassificationReport {
    lock.lock()
    defer { lock.unlock() }

    // Build label distribution
    var labelDistribution: [String: [String: ClassificationReport.LabelStats]] = [:]
    for (category, categoryLabels) in labels {
      var categoryStats: [String: ClassificationReport.LabelStats] = [:]
      let total = categoryLabels.values.reduce(0, +)
      for (label, count) in categoryLabels {
        let percentage = total > 0 ? (Double(count) / Double(total)) * 100.0 : 0.0
        categoryStats[label] = ClassificationReport.LabelStats(count: count, percentage: percentage)
      }
      labelDistribution[category] = categoryStats
    }

    // Build coverage results
    var coverageResults: [String: ClassificationReport.CoverageResult] = [:]
    for (name, check) in coverageChecks {
      let percentage = check.checks > 0 ? (Double(check.hits) / Double(check.checks)) * 100.0 : 0.0
      coverageResults[name] = ClassificationReport.CoverageResult(
        name: name,
        hits: check.hits,
        checks: check.checks,
        percentage: percentage,
        threshold: check.threshold,
        met: percentage >= check.threshold
      )
    }

    return ClassificationReport(
      labelDistribution: labelDistribution,
      coverageResults: coverageResults,
      totalIterations: iterationCount
    )
  }

  /// Check if all coverage thresholds are met.
  ///
  /// - Returns: Array of unmet coverage check names, empty if all met
  public func unmetCoverageThresholds() -> [String] {
    lock.lock()
    defer { lock.unlock() }

    return coverageChecks.compactMap { name, check in
      let percentage = check.checks > 0 ? (Double(check.hits) / Double(check.checks)) * 100.0 : 0.0
      return percentage < check.threshold ? name : nil
    }
  }
}
