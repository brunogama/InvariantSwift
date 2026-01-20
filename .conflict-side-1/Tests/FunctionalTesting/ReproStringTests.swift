import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

/// Tests for `ReproString` round-trip parsing and deterministic reproduction.
struct ReproStringTests {

  // MARK: - Round-Trip Tests

  @Test("ReproString round-trip: predicateFailed")
  func roundTripPredicateFailed() {
    let original = ReproString(
      seed: 12_345_678,
      iteration: 42,
      shrunkDescription: "[1, 2, 3]",
      reason: .predicateFailed
    )

    let serialized = original.description
    let parsed = ReproString.parse(serialized)

    #expect(parsed != nil, "Parsing should succeed")
    #expect(parsed == original, "Round-trip should preserve all fields")
  }

  @Test("ReproString round-trip: threwError")
  func roundTripThrewError() {
    let original = ReproString(
      seed: 98_765_432,
      iteration: 7,
      shrunkDescription: "SomeValue",
      reason: .threwError("division by zero")
    )

    let serialized = original.description
    let parsed = ReproString.parse(serialized)

    #expect(parsed != nil, "Parsing should succeed")
    #expect(parsed == original, "Round-trip should preserve all fields including error message")
  }

  @Test("ReproString round-trip: timedOut")
  func roundTripTimedOut() {
    let original = ReproString(
      seed: 1_111_111_111,
      iteration: 100,
      shrunkDescription: "LongRunningInput",
      reason: .timedOut(seconds: 30.5)
    )

    let serialized = original.description
    let parsed = ReproString.parse(serialized)

    #expect(parsed != nil, "Parsing should succeed")
    #expect(parsed == original, "Round-trip should preserve timeout seconds")
  }

  // MARK: - Format Tests

  @Test("ReproString format matches expected pattern")
  func formatMatchesExpectedPattern() {
    let repro = ReproString(
      seed: 42,
      iteration: 1,
      shrunkDescription: "test",
      reason: .predicateFailed
    )

    let output = repro.description

    #expect(output.hasPrefix("REPRO:"), "Should start with REPRO: prefix")
    #expect(output.contains("seed=42"), "Should contain seed")
    #expect(output.contains("iter=1"), "Should contain iteration")
    #expect(output.contains("shrunk=\"test\""), "Should contain quoted shrunk description")
    #expect(output.contains("reason=predicateFailed"), "Should contain reason")
  }

  // MARK: - Parse Edge Cases

  @Test("ReproString parse rejects invalid prefix")
  func parseRejectsInvalidPrefix() {
    let result = ReproString.parse("INVALID:seed=123,iter=1,shrunk=\"x\",reason=predicateFailed")
    #expect(result == nil, "Should reject string without REPRO: prefix")
  }

  @Test("ReproString parse rejects missing seed")
  func parseRejectsMissingSeed() {
    let result = ReproString.parse("REPRO:iter=1,shrunk=\"x\",reason=predicateFailed")
    #expect(result == nil, "Should reject string without seed")
  }

  @Test("ReproString parse rejects missing iteration")
  func parseRejectsMissingIteration() {
    let result = ReproString.parse("REPRO:seed=123,shrunk=\"x\",reason=predicateFailed")
    #expect(result == nil, "Should reject string without iter")
  }

  @Test("ReproString parse rejects missing shrunk")
  func parseRejectsMissingShrunk() {
    let result = ReproString.parse("REPRO:seed=123,iter=1,reason=predicateFailed")
    #expect(result == nil, "Should reject string without shrunk")
  }

  @Test("ReproString parse handles empty shrunk description")
  func parseHandlesEmptyShrunk() {
    let result = ReproString.parse("REPRO:seed=123,iter=1,shrunk=\"\",reason=predicateFailed")
    #expect(result != nil, "Should accept empty shrunk description")
    #expect(result?.shrunkDescription == "", "Shrunk should be empty string")
  }

  @Test("ReproString parse handles special characters in shrunk")
  func parseHandlesSpecialCharacters() {
    let original = ReproString(
      seed: 999,
      iteration: 5,
      shrunkDescription: "hello, world",
      reason: .predicateFailed
    )

    let serialized = original.description
    let parsed = ReproString.parse(serialized)

    #expect(parsed?.shrunkDescription == "hello, world", "Should preserve comma in description")
  }

  // MARK: - PropertyResult Integration

  @Test("PropertyResult.reproString returns nil for success")
  func reproStringNilForSuccess() {
    let result: PropertyResult<Int> = .success(iterations: 100)
    #expect(result.reproString == nil, "Success should not have reproString")
  }

  @Test("PropertyResult.reproString returns nil for gaveUp")
  func reproStringNilForGaveUp() {
    let result: PropertyResult<Int> = .gaveUp(discarded: 50, iterations: 100)
    #expect(result.reproString == nil, "GaveUp should not have reproString")
  }

  @Test("PropertyResult.reproString returns value for failure")
  func reproStringForFailure() {
    let result: PropertyResult<Int> = .failure(
      counterexample: 42,
      iterations: 10,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 12345)
    )

    let repro = result.reproString
    #expect(repro != nil, "Failure should have reproString")
    #expect(repro?.seed == 12345, "Should have correct seed")
    #expect(repro?.iteration == 10, "Should have correct iteration")
    #expect(repro?.shrunkDescription == "1", "Should have shrunk description")
    #expect(repro?.reason == .predicateFailed, "Should have correct reason")
  }

  // MARK: - FailureReason Tests

  @Test("FailureReason description for predicateFailed")
  func failureReasonPredicateFailed() {
    let reason = FailureReason.predicateFailed
    #expect(reason.description == "predicate returned false")
  }

  @Test("FailureReason description for threwError")
  func failureReasonThrewError() {
    let reason = FailureReason.threwError("test error")
    #expect(reason.description == "threw error: test error")
  }

  @Test("FailureReason description for timedOut")
  func failureReasonTimedOut() {
    let reason = FailureReason.timedOut(seconds: 5.5)
    #expect(reason.description == "timed out after 5.5s")
  }

  @Test("FailureReason equality")
  func failureReasonEquality() {
    #expect(FailureReason.predicateFailed == FailureReason.predicateFailed)
    #expect(FailureReason.threwError("a") == FailureReason.threwError("a"))
    #expect(FailureReason.threwError("a") != FailureReason.threwError("b"))
    #expect(FailureReason.timedOut(seconds: 1.0) == FailureReason.timedOut(seconds: 1.0))
    #expect(FailureReason.timedOut(seconds: 1.0) != FailureReason.timedOut(seconds: 2.0))
  }
}
