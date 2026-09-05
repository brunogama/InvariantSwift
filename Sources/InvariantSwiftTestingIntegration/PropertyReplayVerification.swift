import InvariantSwiftCore
import Testing

internal func verifyPersistedReplay<T: Sendable>(
  _ result: PropertyResult<T>,
  expectedFailure: PersistedFailure,
  testName: String,
  context: PropertyIssueContext
) {
  let expected = ReplayExpectation(
    failure: expectedFailure,
    testName: testName,
    context: context
  )
  verifyReplayResult(result, expected: expected)
}

private struct ReplayExpectation {
  let failure: PersistedFailure
  let testName: String
  let context: PropertyIssueContext
}

private struct ReplayFailureOutcome {
  let iterations: Int
  let shrunkValue: String
  let reason: String
  let seed: Seed?
}

private func verifyReplayResult<T: Sendable>(
  _ result: PropertyResult<T>,
  expected: ReplayExpectation
) {
  switch result {
  case .failure(_, let iterations, let shrunk, let reason, let seed):
    let outcome = ReplayFailureOutcome(
      iterations: iterations,
      shrunkValue: stringifyValue(shrunk),
      reason: reason.description,
      seed: seed
    )
    verifyReplayFailure(outcome, expected: expected)

  case .success, .gaveUp:
    recordReplayNoLongerFails(expected)
  }
}

private func verifyReplayFailure(
  _ outcome: ReplayFailureOutcome,
  expected: ReplayExpectation
) {
  let matchesReason =
    expected.failure.failureReason.map { $0 == outcome.reason } ?? true

  guard outcome.shrunkValue == expected.failure.shrunkValue,
    matchesReason
  else {
    recordMismatch(outcome, expected: expected)
    return
  }
}

private func recordMismatch(
  _ outcome: ReplayFailureOutcome,
  expected: ReplayExpectation
) {
  let context = expected.context
  let location = makeSourceLocation(file: context.file, line: context.line)
  recordReplayProblem(
    "Persisted replay case no longer reproduces the stored counterexample for \(expected.testName).",
    expectedShrunkValue: expected.failure.shrunkValue,
    location: location
  )
  recordAttachment(
    outcome.shrunkValue,
    named: "actual-counterexample.txt",
    location: location
  )
  recordMismatchRunRecord(outcome, expected: expected, location: location)
}

private func recordMismatchRunRecord(
  _ outcome: ReplayFailureOutcome,
  expected: ReplayExpectation,
  location: Testing.SourceLocation
) {
  let record = PropertyRunRecord(
    testName: expected.testName,
    seed: outcome.seed?.rawValue,
    iterations: outcome.iterations,
    outcome: "failure",
    reason: outcome.reason,
    reproductionCommand: expected.failure.reproductionCommand
  )
  recordRunJSON(record, context: expected.context, location: location)
}

private func recordReplayProblem(
  _ message: String,
  expectedShrunkValue: String,
  location: Testing.SourceLocation
) {
  Issue.record(Comment(rawValue: message), sourceLocation: location)
  recordAttachment(
    expectedShrunkValue,
    named: "expected-counterexample.txt",
    location: location
  )
}

private func recordReplayNoLongerFails(_ expected: ReplayExpectation) {
  let context = expected.context
  let location = makeSourceLocation(file: context.file, line: context.line)
  recordReplayProblem(
    "Persisted replay case no longer fails for \(expected.testName).",
    expectedShrunkValue: expected.failure.shrunkValue,
    location: location
  )
}
