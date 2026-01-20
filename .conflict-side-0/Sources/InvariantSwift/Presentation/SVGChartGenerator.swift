/// SVGChartGenerator.swift - Generate SVG charts for property test visualizations
///
/// Provides utilities for creating distribution histograms and shrinking path visualizations
/// as SVG markup for embedding in HTML reports.

import Foundation
import InvariantSwiftCore

/// Generates SVG charts for property test visualization
public struct SVGChartGenerator: Sendable {

  // MARK: - Configuration

  public struct ChartConfig: Sendable {
    public let width: Int
    public let height: Int
    public let barColor: String
    public let backgroundColor: String
    public let textColor: String
    public let gridColor: String

    public init(
      width: Int = 800,
      height: Int = 400,
      barColor: String = "#4A90E2",
      backgroundColor: String = "#FFFFFF",
      textColor: String = "#333333",
      gridColor: String = "#E0E0E0"
    ) {
      self.width = width
      self.height = height
      self.barColor = barColor
      self.backgroundColor = backgroundColor
      self.textColor = textColor
      self.gridColor = gridColor
    }

    public static let `default` = Self()
  }

  private let config: ChartConfig

  public init(config: ChartConfig = .default) {
    self.config = config
  }

  // MARK: - Distribution Histogram

  /// Generate SVG histogram from label distribution data
  /// - Parameters:
  ///   - labels: Array of (label, count) tuples to visualize
  ///   - title: Chart title
  /// - Returns: SVG markup as String
  public func distributionHistogram(
    labels: [(String, Int)],
    title: String = "Input Distribution"
  ) -> String {
    guard !labels.isEmpty else {
      return emptyChartSVG(title: title, message: "No data to display")
    }

    let maxCount = labels.map(\.1).max() ?? 1
    let margin = 60
    let chartWidth = config.width - 2 * margin
    let chartHeight = config.height - 100
    let barWidth = chartWidth / labels.count
    let scaleY = Double(chartHeight) / Double(maxCount)

    var svg = svgHeader()
    svg += drawBackground()
    svg += drawTitle(title: title)

    for (index, (label, count)) in labels.enumerated() {
      let x = margin + index * barWidth
      let barHeight = Int(Double(count) * scaleY)
      let y = margin + 40 + (chartHeight - barHeight)

      svg += """
          <rect x="\(x)" y="\(y)" width="\(barWidth - 4)" height="\(barHeight)" fill="\(config.barColor)" opacity="0.8"/>

        """

      let labelY = config.height - 20
      let labelText = truncateLabel(label, maxLength: 15)
      svg += """
          <text x="\(x + barWidth / 2)" y="\(labelY)" font-family="Arial, sans-serif" \
          font-size="10" text-anchor="middle" fill="\(config.textColor)">\(escapeXML(labelText))</text>

        """

      let countY = y - 5
      svg += """
          <text x="\(x + barWidth / 2)" y="\(countY)" font-family="Arial, sans-serif" \
          font-size="10" text-anchor="middle" fill="\(config.textColor)">\(count)</text>

        """
    }

    svg += svgFooter()
    return svg
  }

  /// Generate SVG histogram showing value distribution
  /// - Parameters:
  ///   - values: Array of numeric values to visualize
  ///   - bins: Number of histogram bins (default: 20)
  ///   - title: Chart title
  /// - Returns: SVG markup as String
  public func generateHistogram<T: Numeric & Comparable>(
    values: [T],
    bins: Int = 20,
    title: String = "Value Distribution"
  ) -> String {
    guard !values.isEmpty else {
      return emptyChartSVG(title: title, message: "No data to display")
    }

    let histogram = createHistogram(values: values, bins: bins)

    var svg = svgHeader()
    svg += drawBackground()
    svg += drawTitle(title: title)
    svg += drawHistogramBars(histogram: histogram)
    svg += drawXAxis(histogram: histogram)
    let maxCount = histogram.map(\.count).max() ?? 0
    svg += drawYAxis(maxCount: maxCount)
    svg += svgFooter()

    return svg
  }

  // MARK: - Shrinking Path Visualization

  /// Generate SVG showing shrinking progression
  /// - Parameters:
  ///   - shrinkPath: Array of values in shrinking sequence
  ///   - title: Chart title
  /// - Returns: SVG markup as String
  public func generateShrinkingPath<T: CustomStringConvertible>(
    shrinkPath: [T],
    title: String = "Shrinking Path"
  ) -> String {
    guard !shrinkPath.isEmpty else {
      return emptyChartSVG(title: title, message: "No shrinking occurred")
    }

    var svg = svgHeader()
    svg += drawBackground()
    svg += drawTitle(title: title)
    svg += drawShrinkingNodes(path: shrinkPath)
    svg += svgFooter()

    return svg
  }

  // MARK: - Private Helpers

  private struct HistogramBin<T: Numeric & Comparable>: Sendable {
    let range: ClosedRange<Double>
    let count: Int
  }

  private func createHistogram<T: Numeric & Comparable>(
    values: [T],
    bins: Int
  ) -> [HistogramBin<T>] {
    // Convert to Double for range calculations
    let doubleValues = values.map { value -> Double in
      if let intValue = value as? Int {
        return Double(intValue)
      } else if let doubleValue = value as? Double {
        return doubleValue
      }
      return 0.0
    }

    guard let minVal = doubleValues.min(),
      let maxVal = doubleValues.max(),
      minVal < maxVal
    else {
      return []
    }

    let binWidth = (maxVal - minVal) / Double(bins)

    return (0..<bins).map { i in
      let rangeStart = minVal + Double(i) * binWidth
      let rangeEnd = i == bins - 1 ? maxVal : rangeStart + binWidth
      let range = rangeStart...rangeEnd

      let count = doubleValues.filter { value in
        let inRange = (value >= rangeStart)
        return i == bins - 1 ? (inRange && value <= rangeEnd) : (inRange && value < rangeEnd)
      }.count

      return HistogramBin(range: range, count: count)
    }
  }

  private func svgHeader() -> String {
    """
    <svg width="\(config.width)" height="\(config.height)" xmlns="http://www.w3.org/2000/svg">

    """
  }

  private func svgFooter() -> String {
    "</svg>"
  }

  private func drawBackground() -> String {
    """
      <rect width="\(config.width)" height="\(config.height)" fill="\(config.backgroundColor)"/>

    """
  }

  private func drawTitle(title: String) -> String {
    let x = config.width / 2
    return """
        <text x="\(x)" y="30" font-family="Arial, sans-serif" font-size="20" font-weight="bold" text-anchor="middle" fill="\(config.textColor)">\(escapeXML(title))</text>

      """
  }

  private func drawHistogramBars<T>(histogram: [HistogramBin<T>]) -> String {
    guard let maxCount = histogram.max(by: { $0.count < $1.count })?.count, maxCount > 0 else {
      return ""
    }

    let margin = 60
    let chartWidth = config.width - 2 * margin
    let chartHeight = config.height - 100
    let barWidth = chartWidth / histogram.count

    var svg = ""
    for (index, bin) in histogram.enumerated() {
      let barHeight = (Double(bin.count) / Double(maxCount)) * Double(chartHeight)
      let x = margin + index * barWidth
      let y = margin + 40 + (chartHeight - Int(barHeight))

      svg += """
          <rect x="\(x)" y="\(y)" width="\(barWidth - 2)" height="\(Int(barHeight))" fill="\(config.barColor)" opacity="0.8"/>

        """
    }

    return svg
  }

  private func drawXAxis<T>(histogram: [HistogramBin<T>]) -> String {
    let margin = 60
    let chartWidth = config.width - 2 * margin
    let y = config.height - 40

    var svg = ""

    // Draw axis line
    svg += """
        <line x1="\(margin)" y1="\(y)" x2="\(margin + chartWidth)" y2="\(y)" stroke="\(config.gridColor)" stroke-width="2"/>

      """

    // Draw labels (first, middle, last)
    if let first = histogram.first, let last = histogram.last {
      let labelY = y + 20

      svg += """
          <text x="\(margin)" y="\(labelY)" font-family="Arial, sans-serif" font-size="12" text-anchor="start" fill="\(config.textColor)">\(String(format: "%.1f", first.range.lowerBound))</text>

        """

      svg += """
          <text x="\(margin + chartWidth)" y="\(labelY)" font-family="Arial, sans-serif" font-size="12" text-anchor="end" fill="\(config.textColor)">\(String(format: "%.1f", last.range.upperBound))</text>

        """
    }

    return svg
  }

  private func drawYAxis(maxCount: Int) -> String {
    let margin = 60
    let chartHeight = config.height - 100
    let x = margin
    let y1 = margin + 40
    let y2 = y1 + chartHeight

    var svg = ""

    // Draw axis line
    svg += """
        <line x1="\(x)" y1="\(y1)" x2="\(x)" y2="\(y2)" stroke="\(config.gridColor)" stroke-width="2"/>

      """

    // Draw max count label
    svg += """
        <text x="\(x - 10)" y="\(y1)" font-family="Arial, sans-serif" font-size="12" text-anchor="end" fill="\(config.textColor)">\(maxCount)</text>

      """

    // Draw zero label
    svg += """
        <text x="\(x - 10)" y="\(y2)" font-family="Arial, sans-serif" font-size="12" text-anchor="end" fill="\(config.textColor)">0</text>

      """

    return svg
  }

  private func drawShrinkingNodes<T: CustomStringConvertible>(path: [T]) -> String {
    let margin = 60
    let nodeRadius = 20
    let nodeSpacing = (config.width - 2 * margin) / max(path.count - 1, 1)
    let centerY = config.height / 2

    var svg = ""

    // Draw connections
    for i in 0..<(path.count - 1) {
      let x1 = margin + i * nodeSpacing
      let x2 = margin + (i + 1) * nodeSpacing

      svg += """
          <line x1="\(x1)" y1="\(centerY)" x2="\(x2)" y2="\(centerY)" stroke="\(config.gridColor)" stroke-width="3" marker-end="url(#arrowhead)"/>

        """
    }

    // Define arrow marker
    svg += """
        <defs>
          <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
            <polygon points="0 0, 10 3, 0 6" fill="\(config.gridColor)"/>
          </marker>
        </defs>

      """

    // Draw nodes
    for (index, value) in path.enumerated() {
      let x = margin + index * nodeSpacing
      let isFirst = index == 0
      let isLast = index == path.count - 1
      let fillColor = isLast ? "#E74C3C" : (isFirst ? "#2ECC71" : config.barColor)

      svg += """
          <circle cx="\(x)" cy="\(centerY)" r="\(nodeRadius)" fill="\(fillColor)" stroke="\(config.textColor)" stroke-width="2"/>

        """

      let labelY = centerY + nodeRadius + 20
      let label = truncateLabel(String(describing: value), maxLength: 10)
      svg += """
          <text x="\(x)" y="\(labelY)" font-family="Arial, sans-serif" font-size="11" text-anchor="middle" fill="\(config.textColor)">\(escapeXML(label))</text>

        """
    }

    return svg
  }

  private func emptyChartSVG(title: String, message: String) -> String {
    var svg = svgHeader()
    svg += drawBackground()
    svg += drawTitle(title: title)

    let centerX = config.width / 2
    let centerY = config.height / 2

    svg += """
        <text x="\(centerX)" y="\(centerY)" font-family="Arial, sans-serif" font-size="16" text-anchor="middle" fill="\(config.textColor)" opacity="0.6">\(escapeXML(message))</text>

      """

    svg += svgFooter()
    return svg
  }

  private func escapeXML(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&apos;")
  }

  private func truncateLabel(_ text: String, maxLength: Int) -> String {
    text.count > maxLength ? String(text.prefix(maxLength - 1)) + "…" : text
  }
}
