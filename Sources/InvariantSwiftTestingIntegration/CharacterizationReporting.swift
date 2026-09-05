import Testing

protocol CharacterizationDifferenceReporting: Sendable {
  func record(name: String, differences: [CharacterizationDifference])
}

struct SwiftTestingDifferenceReporter: CharacterizationDifferenceReporting {
  func record(name: String, differences: [CharacterizationDifference]) {
    recordDifferencesIfNeeded(name: name, differences: differences)
  }
}

final class CapturingDifferenceReporter: CharacterizationDifferenceReporting,
  @unchecked Sendable
{
  typealias Report = (name: String, differences: [CharacterizationDifference])
  private(set) var reports: [Report] = []

  func record(name: String, differences: [CharacterizationDifference]) {
    guard !differences.isEmpty else { return }
    reports.append((name: name, differences: differences))
  }
}

private func recordDifferencesIfNeeded(
  name: String,
  differences: [CharacterizationDifference]
) {
  guard !differences.isEmpty else { return }
  let details =
    differences
    .map { "[\($0.caseID)] \($0.message)" }
    .joined(separator: "\n")
  Issue.record(Comment(rawValue: "Characterization '\(name)' found differences:\n\(details)"))
}
