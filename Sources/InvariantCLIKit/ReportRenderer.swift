import Foundation

struct ReportRenderer: Sendable {
  private let now: @Sendable () -> Date

  init(now: @escaping @Sendable () -> Date = Date.init) {
    self.now = now
  }

  func render(format: ReportFormat) -> String {
    let report = Report(timestamp: now())
    switch format {
    case .json:
      return renderJSON(report)

    case .html:
      return renderHTML(report)

    case .markdown:
      return renderMarkdown(report)

    case .csv:
      return renderCSV(report)
    }
  }

  private func renderJSON(_ report: Report) -> String {
    let object: [String: Any] = [
      "timestamp": timestamp(report.timestamp),
      "totalTests": report.totalTests,
      "passedTests": report.passedTests,
      "failedTests": report.failedTests,
      "duration": report.duration,
      "coverage": report.coverage,
      "successRate": report.successRate,
    ]
    guard
      let data = try? JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys]
      ),
      let value = String(data: data, encoding: .utf8)
    else { return "{}\n" }
    return value + "\n"
  }

  private func renderHTML(_ report: Report) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head><title>FuncTest Report</title></head>
    <body>
      <h1>FuncTest Report</h1>
      <p>Generated: \(timestamp(report.timestamp))</p>
      <p>Total Tests: \(report.totalTests)</p>
      <p>Passed: \(report.passedTests)</p>
      <p>Failed: \(report.failedTests)</p>
      <p>Duration: \(report.duration)s</p>
      <p>Coverage: \(report.coverage * 100)%</p>
    </body>
    </html>
    """ + "\n"
  }

  private func renderMarkdown(_ report: Report) -> String {
    """
    # FuncTest Report

    **Generated:** \(timestamp(report.timestamp))

    | Metric | Value |
    |--------|-------|
    | Total Tests | \(report.totalTests) |
    | Passed | \(report.passedTests) |
    | Failed | \(report.failedTests) |
    | Duration | \(report.duration)s |
    | Coverage | \(report.coverage * 100)% |
    | Success Rate | \(report.successRate * 100)% |
    """ + "\n"
  }

  private func renderCSV(_ report: Report) -> String {
    """
    timestamp,total_tests,passed_tests,failed_tests,duration,coverage,success_rate
    \(csvField(timestamp(report.timestamp))),\(report.totalTests),\(report.passedTests),\(report.failedTests),\(report.duration),\(report.coverage),\(report.successRate)
    """ + "\n"
  }

  private func csvField(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }

  private func timestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateStyle = .full
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}

private struct Report {
  let timestamp: Date
  let totalTests = 42
  let passedTests = 40
  let failedTests = 2
  let duration = 12.34
  let coverage = 0.87

  var successRate: Double {
    Double(passedTests) / Double(totalTests)
  }
}
