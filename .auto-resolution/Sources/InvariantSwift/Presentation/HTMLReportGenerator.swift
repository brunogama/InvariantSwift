/// HTMLReportGenerator.swift - Generate HTML reports from property test results
///
/// Produces self-contained HTML documents with embedded CSS for visualizing
/// property test outcomes, input distributions, and shrinking paths.

import Foundation

/// Generates HTML reports from property test results
public struct HTMLReportGenerator: Sendable {

  // MARK: - Types

  /// Data for report generation
  public struct ReportData: Sendable {
    public let testName: String
    public let result: String  // "passed", "failed", "gave_up"
    public let iterations: Int
    public let shrinkSteps: Int?
    public let counterexample: String?
    public let shrunkValue: String?
    public let classification: ClassificationReport?
    public let shrinkPath: [String]?
    public let timestamp: Date
    public let duration: TimeInterval?
    public let seed: UInt64?

    public init(
      testName: String,
      result: String,
      iterations: Int,
      shrinkSteps: Int? = nil,
      counterexample: String? = nil,
      shrunkValue: String? = nil,
      classification: ClassificationReport? = nil,
      shrinkPath: [String]? = nil,
      timestamp: Date,
      duration: TimeInterval? = nil,
      seed: UInt64? = nil
    ) {
      self.testName = testName
      self.result = result
      self.iterations = iterations
      self.shrinkSteps = shrinkSteps
      self.counterexample = counterexample
      self.shrunkValue = shrunkValue
      self.classification = classification
      self.shrinkPath = shrinkPath
      self.timestamp = timestamp
      self.duration = duration
      self.seed = seed
    }
  }

  private let chartGenerator: SVGChartGenerator

  public init(chartConfig: SVGChartGenerator.ChartConfig = .default) {
    self.chartGenerator = SVGChartGenerator(config: chartConfig)
  }

  // MARK: - Report Generation

  /// Generates a complete HTML report
  public func generate(from data: ReportData) -> String {
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Property Test Report: \(escapeHTML(data.testName))</title>
      <style>
        \(embeddedCSS)
      </style>
    </head>
    <body>
      <div class="container">
        \(headerSection(data))
        \(summarySection(data))
        \(distributionSection(data))
        \(shrinkingSection(data))
        \(detailsSection(data))
        \(footerSection(data))
      </div>
    </body>
    </html>
    """
  }

  // MARK: - Utilities

  private func escapeHTML(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}

// MARK: - CSS Styling

extension HTMLReportGenerator {

  fileprivate var embeddedCSS: String {
    """
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu,
        sans-serif;
      line-height: 1.6;
      color: #333;
      background: #f5f5f5;
    }
    .container {
      max-width: 1000px;
      margin: 20px auto;
      background: white;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
      border-radius: 8px;
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      text-align: center;
    }
    .header h1 {
      font-size: 28px;
      margin-bottom: 10px;
    }
    .status-badge {
      display: inline-block;
      padding: 8px 16px;
      border-radius: 20px;
      font-weight: bold;
      font-size: 14px;
      margin-top: 10px;
    }
    .status-passed { background: #27ae60; color: white; }
    .status-failed { background: #e74c3c; color: white; }
    .status-gave_up { background: #f39c12; color: white; }
    .section {
      padding: 30px;
      border-bottom: 1px solid #e0e0e0;
    }
    .section:last-child {
      border-bottom: none;
    }
    .section h2 {
      font-size: 20px;
      margin-bottom: 20px;
      color: #2c3e50;
    }
    .metrics {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      margin-bottom: 20px;
    }
    .metric {
      background: #f8f9fa;
      padding: 20px;
      border-radius: 8px;
      text-align: center;
    }
    .metric-value {
      font-size: 32px;
      font-weight: bold;
      color: #667eea;
      display: block;
    }
    .metric-label {
      font-size: 12px;
      color: #666;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-top: 5px;
    }
    .chart {
      margin: 20px 0;
      text-align: center;
    }
    pre {
      background: #f8f9fa;
      padding: 15px;
      border-radius: 4px;
      overflow-x: auto;
      font-size: 13px;
      border-left: 4px solid #667eea;
    }
    .footer {
      background: #f8f9fa;
      padding: 20px 30px;
      text-align: center;
      font-size: 12px;
      color: #666;
    }
    .detail-row {
      margin-bottom: 15px;
    }
    .detail-label {
      font-weight: bold;
      color: #555;
      margin-bottom: 5px;
    }
    """
  }
}

// MARK: - HTML Sections

extension HTMLReportGenerator {

  fileprivate func headerSection(_ data: ReportData) -> String {
    let statusClass = "status-\(data.result)"
    let statusText = data.result.uppercased().replacingOccurrences(of: "_", with: " ")
    return """
      <div class="header">
        <h1>\(escapeHTML(data.testName))</h1>
        <span class="status-badge \(statusClass)">\(statusText)</span>
      </div>
      """
  }

  private func summarySection(_ data: ReportData) -> String {
    var metrics = """
      <div class="section">
        <h2>Summary</h2>
        <div class="metrics">
          <div class="metric">
            <span class="metric-value">\(data.iterations)</span>
            <span class="metric-label">Iterations</span>
          </div>
      """

    if let shrinkSteps = data.shrinkSteps {
      metrics += """
          <div class="metric">
            <span class="metric-value">\(shrinkSteps)</span>
            <span class="metric-label">Shrink Steps</span>
          </div>
        """
    }

    if let duration = data.duration {
      let durationStr = String(format: "%.2f", duration)
      metrics += """
          <div class="metric">
            <span class="metric-value">\(durationStr)s</span>
            <span class="metric-label">Duration</span>
          </div>
        """
    }

    if let seed = data.seed {
      metrics += """
          <div class="metric">
            <span class="metric-value">\(seed)</span>
            <span class="metric-label">Seed</span>
          </div>
        """
    }

    metrics += """
        </div>
      </div>
      """

    return metrics
  }

  private func distributionSection(_ data: ReportData) -> String {
    guard let classification = data.classification else { return "" }

    var allLabels: [(String, Int)] = []
    for (category, labels) in classification.labelDistribution {
      for (label, stats) in labels {
        let fullLabel = "\(category): \(label)"
        allLabels.append((fullLabel, stats.count))
      }
    }

    guard !allLabels.isEmpty else { return "" }

    let chart = chartGenerator.distributionHistogram(labels: allLabels)

    return """
      <div class="section">
        <h2>Input Distribution</h2>
        <div class="chart">\(chart)</div>
      </div>
      """
  }

  private func shrinkingSection(_ data: ReportData) -> String {
    guard let path = data.shrinkPath, !path.isEmpty else { return "" }

    let chart = chartGenerator.generateShrinkingPath(shrinkPath: path)

    return """
      <div class="section">
        <h2>Shrinking Path</h2>
        <p>The counterexample was shrunk through the following sequence:</p>
        <div class="chart">\(chart)</div>
      </div>
      """
  }

  private func detailsSection(_ data: ReportData) -> String {
    var details = """
      <div class="section">
        <h2>Details</h2>
      """

    if let counterexample = data.counterexample {
      details += """
        <div class="detail-row">
          <div class="detail-label">Counterexample:</div>
          <pre>\(escapeHTML(counterexample))</pre>
        </div>
        """
    }

    if let shrunkValue = data.shrunkValue {
      details += """
        <div class="detail-row">
          <div class="detail-label">Shrunk Value:</div>
          <pre>\(escapeHTML(shrunkValue))</pre>
        </div>
        """
    }

    if let classification = data.classification {
      let report = classification.format()
      if !report.isEmpty {
        details += """
          <div class="detail-row">
            <div class="detail-label">Classification Report:</div>
            <pre>\(escapeHTML(report))</pre>
          </div>
          """
      }
    }

    details += """
      </div>
      """

    return details
  }

  fileprivate func footerSection(_ data: ReportData) -> String {
    let formatter = ISO8601DateFormatter()
    let timestamp = formatter.string(from: data.timestamp)

    return """
      <div class="footer">
        Generated on \(timestamp) by InvariantSwift Property Testing Framework
      </div>
      """
  }
}
