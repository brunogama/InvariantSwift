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

private struct PropertyRunRecord {
  let testName: String
  let seed: UInt64?
  let iterations: Int
  let outcome: String
  let reason: String
  let reproductionCommand: String?
}

internal func recordPropertyFailureIssue(
  _ report: FailureReport,
  context: PropertyIssueContext = .init(labels: [])
) {
  let location = makeSourceLocation(file: context.file, line: context.line)
  let message =
    "Property failed after \(report.iterationsBeforeFailure) iterations (\(report.failureReason))."
  Issue.record(Comment(rawValue: message), sourceLocation: location)

  Attachment.record(
    stringifyAttachment(report.originalValue),
    named: "counterexample.txt",
    sourceLocation: location
  )
  Attachment.record(
    stringifyAttachment(report.shrunkValue),
    named: "shrunk-counterexample.txt",
    sourceLocation: location
  )

  let record = PropertyRunRecord(
    testName: report.testName,
    seed: report.seed.rawValue,
    iterations: report.iterationsBeforeFailure,
    outcome: "failure",
    reason: report.failureReason.description,
    reproductionCommand: report.reproductionCommand
  )
  if let propertyRunJSON = propertyRunJSON(for: record, context: context) {
    Attachment.record(propertyRunJSON, named: "property-run.json", sourceLocation: location)
  }

  if let classificationReport = report.classificationReport, !classificationReport.isEmpty {
    Attachment.record(classificationReport, named: "classification.txt", sourceLocation: location)
  }
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
  if let propertyRunJSON = propertyRunJSON(for: record, context: context) {
    Attachment.record(propertyRunJSON, named: "property-run.json", sourceLocation: location)
  }
}

internal func attachClassificationReport(
  _ report: String,
  file: StaticString = #filePath,
  line: UInt = #line
) {
  guard !report.isEmpty else { return }
  Attachment.record(
    report,
    named: "classification.txt",
    sourceLocation: makeSourceLocation(file: file, line: line)
  )
}

internal func currentPropertyTestName(fallback: String = "PropertyTest") -> String {
  Test.current?.displayName ?? Test.current?.name ?? fallback
}

internal func handleGeneratedPropertyResult<T: Sendable>(
  _ result: PropertyResult<T>,
  testName: String,
  persistFailures: Bool,
  context: PropertyIssueContext
) {
  switch result {
  case .success:
    break

  case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
    let report = FailureReport(
      testName: testName,
      seed: seed,
      originalValue: stringifyValue(counterexample),
      shrunkValue: stringifyValue(shrunk),
      iterationsBeforeFailure: iterations,
      shrinkAttempts: 0,
      successfulShrinks: 0,
      failureReason: reason,
      totalTime: 0
    )
    FailureReporter(verbose: false).recordFailure(
      report,
      labels: context.labels,
      file: context.file,
      line: context.line
    )

    if persistFailures {
      try? FailurePersistenceManager().save(PersistedFailure(report: report))
    }

  case .gaveUp(let discarded, let iterations):
    recordPropertyGiveUpIssue(
      testName: testName,
      discarded: discarded,
      iterations: iterations,
      seed: PropertyTestContext.current?.seed,
      context: context
    )
  }
}

internal func verifyPersistedReplay<T: Sendable>(
  _ result: PropertyResult<T>,
  expectedFailure: PersistedFailure,
  testName: String,
  context: PropertyIssueContext
) {
  switch result {
  case .failure(_, let iterations, let shrunk, let reason, let seed):
    let actualShrunkValue = stringifyValue(shrunk)
    let actualReason = reason.description
    let matchesReason = expectedFailure.failureReason.map { $0 == actualReason } ?? true

    guard actualShrunkValue == expectedFailure.shrunkValue, matchesReason else {
      let location = makeSourceLocation(file: context.file, line: context.line)
      Issue.record(
        Comment(
          rawValue:
            "Persisted replay case no longer reproduces the stored counterexample for \(testName)."
        ),
        sourceLocation: location
      )
      Attachment.record(
        expectedFailure.shrunkValue,
        named: "expected-counterexample.txt",
        sourceLocation: location
      )
      Attachment.record(
        actualShrunkValue,
        named: "actual-counterexample.txt",
        sourceLocation: location
      )
      let record = PropertyRunRecord(
        testName: testName,
        seed: seed.rawValue,
        iterations: iterations,
        outcome: "failure",
        reason: actualReason,
        reproductionCommand: expectedFailure.reproductionCommand
      )
      if let propertyRunJSON = propertyRunJSON(for: record, context: context) {
        Attachment.record(propertyRunJSON, named: "property-run.json", sourceLocation: location)
      }
      return
    }

  case .success, .gaveUp:
    let location = makeSourceLocation(file: context.file, line: context.line)
    Issue.record(
      Comment(rawValue: "Persisted replay case no longer fails for \(testName)."),
      sourceLocation: location
    )
    Attachment.record(
      expectedFailure.shrunkValue,
      named: "expected-counterexample.txt",
      sourceLocation: location
    )
  }
}

private func makeSourceLocation(file: StaticString, line: UInt) -> Testing.SourceLocation {
  let path = String(describing: file)
  return Testing.SourceLocation(fileID: path, filePath: path, line: Int(line), column: 1)
}

private func propertyRunJSON(
  for record: PropertyRunRecord,
  context: PropertyIssueContext
) -> String? {
  let attachment = PropertyRunAttachment(
    testName: record.testName,
    seed: record.seed,
    iterations: record.iterations,
    outcome: record.outcome,
    reason: record.reason,
    file: String(describing: context.file),
    line: Int(context.line),
    labels: context.labels,
    reproductionCommand: record.reproductionCommand,
    replayFailureID: context.replayFailureID?.uuidString
  )

  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  return try? String(data: encoder.encode(attachment), encoding: .utf8)
}

private func stringifyValue<T>(_ value: T) -> String {
  let printer = PrettyPrinter(config: .testOutput)

  if let printable = value as? PrettyPrintable {
    // swiftlint:disable:next no_print
    return printer.print(printable)
  }

  return String(describing: value)
}

private func stringifyAttachment(_ value: String) -> String {
  value.hasSuffix("\n") ? value : value + "\n"
}

private struct PropertyRunAttachment: Encodable {
  let testName: String
  let seed: UInt64?
  let iterations: Int
  let outcome: String
  let reason: String
  let file: String
  let line: Int
  let labels: [String]
  let reproductionCommand: String?
  let replayFailureID: String?
}

extension PropertyConfig {
  func withExecutionSeed(_ seed: Seed) -> Self {
    PropertyConfig(
      iterations: iterations,
      maxShrinks: maxShrinks,
      maxDiscarded: maxDiscarded,
      seed: seed,
      verbose: verbose,
      timeout: timeout,
      verbosity: verbosity,
      regressionBank: regressionBank,
      propertyId: propertyId,
      failingExampleDatabase: failingExampleDatabase,
      testIdentifier: testIdentifier,
      replayFirst: replayFirst,
      maxReplayExamples: maxReplayExamples,
      unicodeMode: unicodeMode,
      maxStringShrinkSteps: maxStringShrinkSteps,
      coverage: coverage,
      discard: discard,
      showProgress: showProgress,
      progressInterval: progressInterval
    )
  }

  func replayConfiguration(for failure: PersistedFailure) -> Self {
    PropertyConfig(
      iterations: max(iterations, failure.iterationsBeforeFailure),
      maxShrinks: maxShrinks,
      maxDiscarded: maxDiscarded,
      seed: Seed(value: failure.seed),
      verbose: verbose,
      timeout: timeout,
      verbosity: verbosity,
      regressionBank: nil,
      propertyId: nil,
      failingExampleDatabase: nil,
      testIdentifier: nil,
      replayFirst: false,
      maxReplayExamples: nil,
      unicodeMode: unicodeMode,
      maxStringShrinkSteps: maxStringShrinkSteps,
      coverage: coverage,
      discard: discard,
      showProgress: showProgress,
      progressInterval: progressInterval
    )
  }
}
