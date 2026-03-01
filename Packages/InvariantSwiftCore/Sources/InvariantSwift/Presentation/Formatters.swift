/// Formatting functions for test output: histograms, tables, failures, and coverage.
///
/// Provides console-formatted output for classification histograms, coverage tables,
/// property failure reports, and PropertyResult pretty descriptions.
/// Extracted from PrettyPrint.swift to keep that file under the line budget.

import Foundation
import InvariantSwiftCore

// MARK: - PropertyResult Pretty Description

extension PropertyResult {
  /// **Pretty-print the property result**
  /// - Parameter config: Pretty-printing configuration
  /// - Returns: Formatted result description
  public func prettyDescription(
    config: PrettyConfig = .testOutput
  ) -> String {
    let printer = PrettyPrinter(config: config)

    switch self {
    case .success(let iterations):
      return printer.render(
        .concat(
          .colored(.green, .styled(.bold, .text("Property passed"))),
          .concat(.text(" after "), .colored(.cyan, .text("\(iterations) iterations")))
        )
      )

    case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
      let counterDoc =
        (counterexample as? PrettyPrintable)?.prettyDoc(config: config, depth: 0)
        ?? .text("\(counterexample)")
      let shrunkDoc =
        (shrunk as? PrettyPrintable)?.prettyDoc(config: config, depth: 0) ?? .text("\(shrunk)")

      return printer.render(
        Doc.concat([
          .colored(.red, .styled(.bold, .text("Property failed"))),
          .text(" after "),
          .colored(.cyan, .text("\(iterations) iterations")),
          .text(" (\(reason))"),
          .line,
          .line,
          .colored(.red, .text("Counterexample:")),
          .line,
          .indent(2, counterDoc),
          .line,
          .line,
          .colored(.yellow, .text("Minimal counterexample:")),
          .line,
          .indent(2, shrunkDoc),
          .line,
          .line,
          .colored(.cyan, .text("Seed: \(seed.rawValue)")),
        ])
      )

    case .gaveUp:
      return printer.render(
        .colored(.yellow, .styled(.bold, .text("Property gave up (too many discarded cases)")))
      )
    }
  }
}

// MARK: - Histogram Formatting

/// Format a histogram of values for console output.
///
/// Creates an ASCII bar chart representation of value distributions.
///
/// - Parameters:
///   - category: Category name for the histogram
///   - values: Dictionary of value -> count
///   - maxBars: Maximum bar width (default: 40)
/// - Returns: Formatted histogram string
public func formatHistogram(
  category: String,
  values: [String: Int],
  maxBars: Int = 40
) -> String {
  guard !values.isEmpty else { return "  \(category): (no values)" }

  let total = values.values.reduce(0, +)
  let maxCount = values.values.max() ?? 1

  // Sort by count descending, then alphabetically
  let sorted = values.sorted { first, second in
    if first.value != second.value {
      return first.value > second.value
    }
    return first.key < second.key
  }

  let maxKeyLength = sorted.map(\.key.count).max() ?? 0

  var lines: [String] = []
  lines.append("  \(category):")

  for (key, count) in sorted {
    let percentage = total > 0 ? (Double(count) / Double(total)) * 100.0 : 0
    let barLength = maxCount > 0 ? Int(Double(count) / Double(maxCount) * Double(maxBars)) : 0
    let bar = String(repeating: "=", count: max(1, barLength))

    let paddedKey = key.padding(toLength: maxKeyLength, withPad: " ", startingAt: 0)
    let percentStr = String(format: "%5.1f%%", percentage)
    let countStr = String(format: "%4d", count)

    lines.append("    \(paddedKey) \(bar) \(countStr) (\(percentStr))")
  }

  return lines.joined(separator: "\n")
}

// MARK: - Table Formatting

/// Format a classification table for console output.
///
/// - Parameters:
///   - title: Table title
///   - categories: Dictionary of category -> (label -> stats)
/// - Returns: Formatted table string
public func formatClassificationTable(
  title: String,
  categories: [String: [String: ClassificationReport.LabelStats]]
) -> String {
  guard !categories.isEmpty else { return "" }

  var lines: [String] = []
  lines.append("")
  lines.append("\(title)")
  lines.append(String(repeating: "-", count: 50))

  for category in categories.keys.sorted() {
    guard let labels = categories[category] else { continue }

    lines.append("")
    lines.append("Category: \(category)")

    // Sort by percentage descending
    let sorted = labels.sorted { $0.value.percentage > $1.value.percentage }
    let maxLabelLength = sorted.map(\.key.count).max() ?? 0

    for (label, stats) in sorted {
      let paddedLabel = label.padding(toLength: maxLabelLength, withPad: " ", startingAt: 0)
      let percentStr = String(format: "%.1f%%", stats.percentage)
      lines.append("  \(paddedLabel): \(stats.count) (\(percentStr))")
    }
  }

  return lines.joined(separator: "\n")
}

// MARK: - Failure Formatting

/// Format a property failure with custom messages.
///
/// - Parameters:
///   - result: The failure result
///   - customMessages: Custom messages computed from counterexample closures
///   - classification: Classification report (optional)
/// - Returns: Formatted failure string
public func formatPropertyFailure<T>(
  result: PropertyResult<T>,
  customMessages: [String] = [],
  classification: ClassificationReport? = nil
) -> String where T: CustomStringConvertible {
  guard case .failure(let counterexample, let iterations, let shrunk, let reason, let seed) = result
  else {
    return ""
  }

  var lines: [String] = []

  lines.append("*** Failed! \(reason) after \(iterations) test(s).")
  lines.append("")

  // Custom messages first (if any)
  if !customMessages.isEmpty {
    for message in customMessages {
      lines.append(message)
    }
    lines.append("")
  }

  // Counterexample details
  lines.append("Counterexample:")
  lines.append("  Original: \(counterexample)")
  lines.append("  Shrunk:   \(shrunk)")
  lines.append("")

  // Reproduction info
  lines.append("Reproduce with seed: \(seed.rawValue)")

  // Classification report (if any)
  if let report = classification,
    !report.labelDistribution.isEmpty || !report.coverageResults.isEmpty
  {
    lines.append("")
    lines.append(report.format())
  }

  return lines.joined(separator: "\n")
}

/// Format coverage result with status icon.
public func formatCoverageStatus(_ result: ClassificationReport.CoverageResult) -> String {
  let icon = result.met ? "+" : "x"
  let percentStr = String(format: "%.1f%%", result.percentage)
  let thresholdStr = String(format: "%.1f%%", result.threshold)
  return "\(icon) \(result.name): \(percentStr) (threshold: \(thresholdStr))"
}
