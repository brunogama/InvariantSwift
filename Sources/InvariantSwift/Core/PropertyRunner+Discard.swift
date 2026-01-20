// PropertyRunner+Discard.swift
// InvariantSwift
//
// Discard ratio tracking and enforcement for property testing.

import Foundation

// MARK: - Discard Checking

extension PropertyRunner {
  /// Result of checking discard ratio against thresholds.
  enum DiscardCheckResult {
    /// Ratio is acceptable.
    case ok
    /// Ratio exceeds warning threshold.
    case warn(message: String)
    /// Ratio exceeds failure threshold.
    case fail(message: String)
  }

  /// Check discard ratio against configured thresholds.
  ///
  /// - Parameters:
  ///   - discarded: Number of discarded test cases
  ///   - successful: Number of successful iterations
  ///   - config: Property configuration with discard settings
  ///
  /// - Returns: Check result indicating if action is needed
  func checkDiscardRatio(
    discarded: Int,
    successful: Int,
    config: PropertyConfig
  ) -> DiscardCheckResult {
    guard config.discard.enforceRatio else { return .ok }

    let ratio = successful > 0 ? Double(discarded) / Double(successful) : Double(discarded)

    if ratio > config.discard.failRatio {
      return .fail(
        message: formatDiscardFailure(ratio: ratio, discarded: discarded, successful: successful)
      )
    }

    if ratio > config.discard.warnRatio {
      return .warn(
        message: formatDiscardWarning(ratio: ratio, discarded: discarded, successful: successful)
      )
    }

    return .ok
  }

  /// Format actionable warning message for high discard ratio.
  private func formatDiscardWarning(ratio: Double, discarded: Int, successful: Int) -> String {
    """
    Warning: High discard ratio: \(String(format: "%.1f", ratio))x (\(discarded) discards / \
    \(successful) iterations)

    Common causes:
      - Filter condition too restrictive
      - Generator produces many invalid inputs
      - Precondition rarely satisfied

    Suggestions:
      - Instead of: Gen.int.filter { $0 > 0 }
        Try:        Gen.int(in: 1...)

      - Instead of: array.isEmpty ==> property
        Try:        Gen.array(count: 1...) generator

    Consider redesigning generator to produce valid inputs directly.
    """
  }

  /// Format actionable failure message for excessive discard ratio.
  private func formatDiscardFailure(ratio: Double, discarded: Int, successful: Int) -> String {
    """
    Error: Discard ratio too high: \(String(format: "%.1f", ratio))x (\(discarded) discards / \
    \(successful) iterations)

    The test discarded more than \(Int(ratio))x as many inputs as it successfully tested.
    This indicates the generator or preconditions need redesign.

    Common causes:
      - Filter condition too restrictive
      - Generator produces many invalid inputs
      - Precondition rarely satisfied

    Suggestions:
      - Instead of: Gen.int.filter { $0 > 0 }
        Try:        Gen.int(in: 1...)

      - Instead of: condition ==> property
        Try:        Use Gen.suchThat or Gen.from with targeted generator

    To suppress this error, use PropertyConfig(discard: .lenient) or .disabled
    """
  }

  /// Handle discard check result and return appropriate PropertyResult if needed.
  ///
  /// - Parameters:
  ///   - result: The discard check result
  ///   - discarded: Number of discarded values
  ///   - successful: Number of successful iterations
  ///   - config: Property configuration
  ///
  /// - Returns: PropertyResult.gaveUp if ratio exceeded fail threshold, nil otherwise
  func handleDiscardCheck<T>(
    _ result: DiscardCheckResult,
    discarded: Int,
    successful: Int,
    config: PropertyConfig
  ) -> PropertyResult<T>? {
    switch result {
    case .ok:
      return nil

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }
      return nil

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successful)
    }
  }
}
