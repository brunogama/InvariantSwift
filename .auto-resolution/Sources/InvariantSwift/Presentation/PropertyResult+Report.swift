import Foundation
import InvariantSwiftCore

// MARK: - PropertyResult HTML Report Extension

extension PropertyResult {

  /// Exports test result as HTML report to a file
  ///
  /// Generates a self-contained HTML document with:
  /// - Test outcome summary (pass/fail/gave up)
  /// - Iteration count and shrinking statistics
  /// - Input distribution charts (if classification data provided)
  /// - Shrinking path visualization (if shrink path provided)
  /// - Counterexample and shrunk value details
  ///
  /// - Parameters:
  ///   - url: File URL to write the report
  ///   - testName: Name of the test for the report header
  ///   - classification: Optional classification report for distribution chart
  ///   - shrinkPath: Optional shrink path for visualization
  ///
  /// - Throws: File write errors
  ///
  /// - Example:
  ///   ```swift
  ///   let result = try await checkProperty(myProperty)
  ///   let reportURL = URL(fileURLWithPath: "test_report.html")
  ///   try result.exportHTML(
  ///     to: reportURL,
  ///     testName: "MyPropertyTest",
  ///     classification: classificationReport
  ///   )
  ///   ```
  public func exportHTML(
    to url: URL,
    testName: String,
    classification: ClassificationReport? = nil,
    shrinkPath: [String]? = nil
  ) throws {
    let generator = HTMLReportGenerator()

    let data = HTMLReportGenerator.ReportData(
      testName: testName,
      result: resultString,
      iterations: iterationCount,
      shrinkSteps: shrinkStepCount,
      counterexample: counterexampleDescription,
      shrunkValue: shrunkDescription,
      classification: classification,
      shrinkPath: shrinkPath,
      timestamp: Date(),
      duration: nil as TimeInterval?,
      seed: seedValue
    )

    let html = generator.generate(from: data)
    try html.write(to: url, atomically: true, encoding: String.Encoding.utf8)
  }

  // MARK: - Private Helpers

  private var resultString: String {
    switch self {
    case .success:
      "passed"

    case .failure:
      "failed"

    case .gaveUp:
      "gave_up"
    }
  }

  private var shrinkStepCount: Int? {
    // For now, we don't track shrink step count in PropertyResult
    // Future enhancement: add shrinkSteps to .failure case
    nil
  }

  private var counterexampleDescription: String? {
    guard case .failure(let counterexample, _, _, _, _) = self else {
      return nil
    }
    return String(describing: counterexample)
  }

  private var shrunkDescription: String? {
    guard case .failure(_, _, let shrunk, _, _) = self else {
      return nil
    }
    return String(describing: shrunk)
  }

  private var seedValue: UInt64? {
    guard case .failure(_, _, _, _, let seed) = self else {
      return nil
    }
    return seed.rawValue
  }
}
