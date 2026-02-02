import Testing
import Foundation
@testable import InvariantSwift
@testable import InvariantSwiftCore

@Suite("HTML Report Tests")
struct HTMLReportTests {

  // MARK: - SVG Chart Tests

  @Test("SVG histogram generates valid SVG")
  func svgHistogramValid() {
    let chart = SVGChartGenerator()
    let svg = chart.distributionHistogram(labels: [("small", 50), ("medium", 30), ("large", 20)])

    #expect(svg.contains("<svg"))
    #expect(svg.contains("</svg>"))
    #expect(svg.contains("small"))
    #expect(svg.contains("medium"))
    #expect(svg.contains("large"))
  }

  @Test("SVG histogram handles empty data")
  func svgHistogramEmpty() {
    let chart = SVGChartGenerator()
    let svg = chart.distributionHistogram(labels: [])

    #expect(svg.contains("<svg"))
    #expect(svg.contains("No data to display"))
  }

  @Test("SVG histogram escapes XML properly")
  func svgHistogramEscapesXML() {
    let chart = SVGChartGenerator()
    let svg = chart.distributionHistogram(labels: [("<tag>", 10), ("&amp;", 5)])

    #expect(svg.contains("&lt;tag&gt;"))
    #expect(svg.contains("&amp;amp;"))
  }

  @Test("SVG shrink path generates valid SVG")
  func svgShrinkPathValid() {
    let chart = SVGChartGenerator()
    let svg = chart.generateShrinkingPath(shrinkPath: [100, 50, 25, 12, 6])

    #expect(svg.contains("<svg"))
    #expect(svg.contains("</svg>"))
    #expect(svg.contains("100"))
    #expect(svg.contains("6"))
    #expect(svg.contains("<circle"))
  }

  @Test("SVG shrink path handles single value")
  func svgShrinkPathSingleValue() {
    let chart = SVGChartGenerator()
    let svg = chart.generateShrinkingPath(shrinkPath: [42])

    #expect(svg.contains("<svg"))
    #expect(svg.contains("42"))
    #expect(svg.contains("<circle"))
  }

  @Test("SVG shrink path handles empty data")
  func svgShrinkPathEmpty() {
    let chart = SVGChartGenerator()
    let svg = chart.generateShrinkingPath(shrinkPath: [] as [Int])

    #expect(svg.contains("<svg"))
    #expect(svg.contains("No shrinking occurred"))
  }

  // MARK: - HTML Report Generation Tests

  @Test("HTML report generates valid HTML5")
  func htmlReportValid() {
    let generator = HTMLReportGenerator()
    let data = HTMLReportGenerator.ReportData(
      testName: "TestProperty",
      result: "passed",
      iterations: 100,
      shrinkSteps: nil,
      counterexample: nil,
      shrunkValue: nil,
      classification: nil,
      shrinkPath: nil,
      timestamp: Date(),
      duration: 1.5,
      seed: 12345
    )
    let html = generator.generate(from: data)

    #expect(html.contains("<!DOCTYPE html>"))
    #expect(html.contains("<html lang=\"en\">"))
    #expect(html.contains("TestProperty"))
    #expect(html.contains("PASSED"))
    #expect(html.contains("100"))
  }

  @Test("HTML report includes failure details")
  func htmlReportFailureDetails() {
    let generator = HTMLReportGenerator()
    let data = HTMLReportGenerator.ReportData(
      testName: "FailingTest",
      result: "failed",
      iterations: 42,
      shrinkSteps: 5,
      counterexample: "[1, 2, 3]",
      shrunkValue: "[1]",
      classification: nil,
      shrinkPath: ["[1, 2, 3]", "[1, 2]", "[1]"],
      timestamp: Date(),
      duration: 2.3,
      seed: 67890
    )
    let html = generator.generate(from: data)

    #expect(html.contains("FailingTest"))
    #expect(html.contains("FAILED"))
    #expect(html.contains("42"))
    #expect(html.contains("[1, 2, 3]"))
    #expect(html.contains("[1]"))
    #expect(html.contains("Shrinking Path"))
  }

  @Test("HTML report escapes HTML in content")
  func htmlReportEscapesHTML() {
    let generator = HTMLReportGenerator()
    let data = HTMLReportGenerator.ReportData(
      testName: "<script>alert('xss')</script>",
      result: "failed",
      iterations: 1,
      counterexample: "<div>evil</div>",
      shrunkValue: "&malicious",
      classification: nil,
      shrinkPath: nil,
      timestamp: Date()
    )
    let html = generator.generate(from: data)

    #expect(html.contains("&lt;script&gt;"))
    #expect(!html.contains("<script>alert"))
    #expect(html.contains("&lt;div&gt;"))
    #expect(html.contains("&amp;malicious"))
  }

  @Test("HTML report includes classification")
  func htmlReportWithClassification() {
    let generator = HTMLReportGenerator()
    let labelStats = ClassificationReport.LabelStats(count: 50, percentage: 50.0)
    let classification = ClassificationReport(
      labelDistribution: ["category": ["label": labelStats]],
      coverageResults: [:],
      collectedValues: [:],
      totalIterations: 100
    )
    let data = HTMLReportGenerator.ReportData(
      testName: "ClassifiedTest",
      result: "passed",
      iterations: 100,
      classification: classification,
      shrinkPath: nil,
      timestamp: Date()
    )
    let html = generator.generate(from: data)

    #expect(html.contains("Input Distribution"))
    #expect(html.contains("<svg"))
  }

  @Test("HTML report has inline CSS")
  func htmlReportInlineCSS() {
    let generator = HTMLReportGenerator()
    let data = HTMLReportGenerator.ReportData(
      testName: "Test",
      result: "passed",
      iterations: 1,
      timestamp: Date()
    )
    let html = generator.generate(from: data)

    #expect(html.contains("<style>"))
    #expect(html.contains("font-family:"))
    #expect(html.contains(".container"))
    #expect(!html.contains("<link rel=\"stylesheet\""))
  }

  // MARK: - PropertyResult Export Tests

  @Test("PropertyResult exportHTML writes file")
  func propertyResultExportHTML() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let reportURL = tempDir.appendingPathComponent("test_report_\(UUID().uuidString).html")

    let result: PropertyResult<Int> = .success(iterations: 100)
    try result.exportHTML(to: reportURL, testName: "MyTest")

    let contents = try String(contentsOf: reportURL, encoding: .utf8)
    #expect(contents.contains("MyTest"))
    #expect(contents.contains("PASSED"))
    #expect(contents.contains("100"))

    try? FileManager.default.removeItem(at: reportURL)
  }

  @Test("PropertyResult exportHTML for failure")
  func propertyResultExportHTMLFailure() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let reportURL = tempDir.appendingPathComponent("test_failure_\(UUID().uuidString).html")

    let seed = Seed(value: 42)
    let result: PropertyResult<String> = .failure(
      counterexample: "original",
      iterations: 10,
      shrunk: "o",
      reason: .predicateFailed,
      seed: seed
    )
    try result.exportHTML(
      to: reportURL,
      testName: "FailingTest",
      shrinkPath: ["original", "orig", "or", "o"]
    )

    let contents = try String(contentsOf: reportURL, encoding: .utf8)
    #expect(contents.contains("FailingTest"))
    #expect(contents.contains("FAILED"))
    #expect(contents.contains("original"))
    #expect(contents.contains("Shrinking Path"))

    try? FileManager.default.removeItem(at: reportURL)
  }

  @Test("PropertyResult exportHTML for gaveUp")
  func propertyResultExportHTMLGaveUp() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let reportURL = tempDir.appendingPathComponent("test_gaveup_\(UUID().uuidString).html")

    let result: PropertyResult<Int> = .gaveUp(discarded: 50, iterations: 100)
    try result.exportHTML(to: reportURL, testName: "GaveUpTest")

    let contents = try String(contentsOf: reportURL, encoding: .utf8)
    #expect(contents.contains("GaveUpTest"))
    #expect(contents.contains("GAVE UP"))

    try? FileManager.default.removeItem(at: reportURL)
  }

  // MARK: - Chart Configuration Tests

  @Test("SVG chart respects custom configuration")
  func svgChartCustomConfig() {
    let config = SVGChartGenerator.ChartConfig(
      width: 1200,
      height: 600,
      barColor: "#FF0000",
      backgroundColor: "#000000"
    )
    let chart = SVGChartGenerator(config: config)
    let svg = chart.distributionHistogram(labels: [("test", 10)])

    #expect(svg.contains("width=\"1200\""))
    #expect(svg.contains("height=\"600\""))
    #expect(svg.contains("#FF0000"))
    #expect(svg.contains("#000000"))
  }
}
