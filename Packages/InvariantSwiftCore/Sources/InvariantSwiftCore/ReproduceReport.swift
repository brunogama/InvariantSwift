import Foundation

/// Formatted reproduction information for a failing example.
public struct ReproduceReport: CustomStringConvertible, Sendable {
  public let testIdentifier: TestIdentifier
  public let example: FailingExample
  public let originalInput: String?
  public let shrunkInput: String?
  public let shrinkSteps: Int

  public init(
    testIdentifier: TestIdentifier,
    example: FailingExample,
    originalInput: String? = nil,
    shrunkInput: String? = nil,
    shrinkSteps: Int = 0
  ) {
    self.testIdentifier = testIdentifier
    self.example = example
    self.originalInput = originalInput
    self.shrunkInput = shrunkInput
    self.shrinkSteps = shrinkSteps
  }

  public var description: String {
    var lines = failureLines
    lines.append(contentsOf: inputLines)
    lines.append(contentsOf: reproductionLines)
    lines.append(contentsOf: persistenceLines)
    return lines.joined(separator: "\n")
  }

  private var failureLines: [String] {
    ["❌ Property failed: \(testIdentifier.function)", ""]
  }

  private var inputLines: [String] {
    var lines: [String] = []
    if let input = shrunkInput ?? example.inputDescription {
      lines.append("Input: \(input)")
    }
    if let original = originalInput, shrunkInput != nil {
      lines += ["Shrunk from: \(original)", "Shrink steps: \(shrinkSteps)"]
    }
    return lines
  }

  private var reproductionLines: [String] {
    var lines = ["", "To reproduce this exact failure, add:"]
    lines.append("    \(example.reproduceAnnotation())")
    if let input = example.base64Input {
      lines += ["", "Or with serialized input:", "    @Reproduce(input: \"\(input)\")"]
    }
    return lines
  }

  private var persistenceLines: [String] {
    guard FailingExampleConfig.autoSave else { return [] }
    return ["", "Example saved to: \(URL.defaultFailingExampleURL.path)"]
  }
}
