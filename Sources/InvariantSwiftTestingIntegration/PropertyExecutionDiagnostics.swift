import Foundation
import InvariantSwift
import InvariantSwiftCore
import Testing

internal struct PropertyIssueContext {
  let labels: [String]
  let file: StaticString
  let line: UInt
  let replayFailureID: UUID?

  init(
    labels: [String],
    file: StaticString = #filePath,
    line: UInt = #line,
    replayFailureID: UUID? = nil
  ) {
    self.labels = labels
    self.file = file
    self.line = line
    self.replayFailureID = replayFailureID
  }
}

internal func recordPropertyFailureIssue(
  _ report: FailureReport,
  context: PropertyIssueContext = .init(labels: [])
) {
  let location = makeSourceLocation(file: context.file, line: context.line)
  let message =
    "Property failed after \(report.iterationsBeforeFailure) iterations (\(report.failureReason))."
  Issue.record(Comment(rawValue: message), sourceLocation: location)

  recordCounterexamples(
    original: stringifyAttachment(report.originalValue),
    shrunk: stringifyAttachment(report.shrunkValue),
    location: location
  )

  let record = PropertyRunRecord(
    testName: report.testName,
    seed: report.seed.rawValue,
    iterations: report.iterationsBeforeFailure,
    outcome: "failure",
    reason: report.failureReason.description,
    reproductionCommand: report.reproductionCommand
  )
  recordRunJSON(record, context: context, location: location)
  recordClassificationIfPresent(report.classificationReport, location: location)
}

private func recordCounterexamples(
  original: String,
  shrunk: String,
  location: Testing.SourceLocation
) {
  recordAttachment(original, named: "counterexample.txt", location: location)
  recordAttachment(
    shrunk,
    named: "shrunk-counterexample.txt",
    location: location
  )
}

private func recordClassificationIfPresent(
  _ report: String?,
  location: Testing.SourceLocation
) {
  guard let classificationReport = report else { return }
  guard !classificationReport.isEmpty else { return }
  recordAttachment(
    classificationReport,
    named: "classification.txt",
    location: location
  )
}

internal func recordPropertyGiveUpIssue(
  testName: String,
  discarded: Int,
  iterations: Int,
  seed: UInt64?,
  context: PropertyIssueContext = .init(labels: [])
) {
  let location = makeSourceLocation(file: context.file, line: context.line)
  let message =
    "Property gave up after discarding \(discarded) cases in \(iterations) iterations."
  Issue.record(Comment(rawValue: message), sourceLocation: location)

  let record = PropertyRunRecord(
    testName: testName,
    seed: seed,
    iterations: iterations,
    outcome: "gaveUp",
    reason: "discarded \(discarded) cases",
    reproductionCommand: nil
  )
  recordRunJSON(record, context: context, location: location)
}

internal func attachClassificationReport(
  _ report: String,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  guard !report.isEmpty else { return }
  recordAttachment(
    report,
    named: "classification.txt",
    location: makeSourceLocation(file: file, line: line)
  )
}

internal func currentPropertyTestName(
  fallback: String = "PropertyTest"
) -> String {
  Test.current?.displayName ?? Test.current?.name ?? fallback
}

internal func handleGeneratedPropertyResult<T: Sendable>(
  _ result: PropertyResult<T>,
  testName: String,
  persistFailures: Bool,
  context: PropertyIssueContext
) {
  handleGeneratedResult(
    result,
    settings: GeneratedResultSettings(
      testName: testName,
      persistFailures: persistFailures,
      context: context
    )
  )
}

private struct GeneratedResultSettings {
  let testName: String
  let persistFailures: Bool
  let context: PropertyIssueContext
}

private func handleGeneratedResult<T: Sendable>(
  _ result: PropertyResult<T>,
  settings: GeneratedResultSettings
) {
  switch result {
  case .success:
    break

  case .failure:
    handleGeneratedFailureResult(result, settings: settings)

  case .gaveUp(let discarded, let iterations):
    recordPropertyGiveUpIssue(
      testName: settings.testName,
      discarded: discarded,
      iterations: iterations,
      seed: PropertyTestContext.current?.seed,
      context: settings.context
    )
  }
}

private struct GeneratedFailure {
  let originalValue: String
  let shrunkValue: String
  let iterations: Int
  let reason: FailureReason
  let seed: Seed
}

private func handleGeneratedFailureResult<T: Sendable>(
  _ result: PropertyResult<T>,
  settings: GeneratedResultSettings
) {
  guard
    case .failure(
      let counterexample,
      let iterations,
      let shrunk,
      let reason,
      let seed
    ) = result
  else { return }

  let failure = GeneratedFailure(
    originalValue: stringifyValue(counterexample),
    shrunkValue: stringifyValue(shrunk),
    iterations: iterations,
    reason: reason,
    seed: seed
  )
  handleGeneratedFailure(failure, settings: settings)
}

private func handleGeneratedFailure(
  _ failure: GeneratedFailure,
  settings: GeneratedResultSettings
) {
  let report = FailureReport(
    testName: settings.testName,
    seed: failure.seed,
    originalValue: failure.originalValue,
    shrunkValue: failure.shrunkValue,
    iterationsBeforeFailure: failure.iterations,
    shrinkAttempts: 0,
    successfulShrinks: 0,
    failureReason: failure.reason,
    totalTime: 0
  )
  FailureReporter(verbose: false).recordFailure(
    report,
    labels: settings.context.labels,
    file: settings.context.file,
    line: settings.context.line
  )
  persistFailureIfRequested(report, settings: settings)
}

private func persistFailureIfRequested(
  _ report: FailureReport,
  settings: GeneratedResultSettings
) {
  guard settings.persistFailures else { return }
  do {
    try FailurePersistenceManager().save(PersistedFailure(report: report))
  } catch {
    let context = settings.context
    let location = makeSourceLocation(file: context.file, line: context.line)
    Issue.record(
      Comment(rawValue: "Failed to persist failure for replay: \(error.localizedDescription)"),
      sourceLocation: location
    )
  }
}

internal func makeSourceLocation(
  file: StaticString,
  line: UInt
) -> Testing.SourceLocation {
  let path = String(describing: file)
  return Testing.SourceLocation(
    fileID: path,
    filePath: path,
    line: Int(line),
    column: 1
  )
}

extension PropertyConfig {
  /// Adapts a persisted failure to the focused replay derivation owned by
  /// `PropertyConfig`, which preserves execution settings and clears
  /// persistence so the replay never re-persists or re-replays.
  func replayConfiguration(for failure: PersistedFailure) -> Self {
    replayConfiguration(
      seed: Seed(value: failure.seed),
      minimumIterations: failure.iterationsBeforeFailure
    )
  }
}
