import InvariantSwiftTesting
import Testing

@Suite("Persisted Failure Replay Tests")
struct PersistedFailureReplayTests {
  @Test("executePersistedFailureReplay accepts a matching stored failure")
  func replayHelperAcceptsMatchingFailure() throws {
    let property = Property(generator: Gen.pure(-1)) { value in
      value > 0
    }
    let failure = PersistedFailure(
      testName: "replayHelperAcceptsMatchingFailure",
      seed: 1,
      originalValue: "-1",
      shrunkValue: "-1",
      iterationsBeforeFailure: 1,
      shrinkAttempts: 0,
      failureReason: FailureReason.predicateFailed.description
    )

    try executePersistedFailureReplay(
      property,
      baseConfig: PropertyConfig(iterations: 1, seed: Seed(value: 1)),
      persistedFailure: failure,
      testName: "replayHelperAcceptsMatchingFailure",
      labels: ["value"]
    )
  }
}
