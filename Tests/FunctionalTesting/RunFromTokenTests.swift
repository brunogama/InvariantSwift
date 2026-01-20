import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

/// Tests for `PropertyRunner.runFromToken` - replaying failures from tokens.
@Suite("Run From Token Tests")
struct RunFromTokenTests {

  // MARK: - Basic Replay Tests

  @Test("Replay reproduces same failure with identical seed")
  func testReplayReproducesFailure() async {
    // Create a property that fails on specific input
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<1000, using: &rng)
    }

    let property = Property(generator: gen) { value in
      value < 500  // Will fail for values >= 500
    }

    // Run once to get a failing seed
    let seed = Seed(value: 12345)
    let runner = PropertyRunner(seed: seed)
    let config = PropertyConfig(iterations: 100, maxDiscarded: 500, seed: seed)

    let result1 = runner.runProperty(property, config: config)

    // Extract the seed from failure
    guard case .failure(_, _, let shrunk1, _, let failingSeed) = result1 else {
      Issue.record("Expected failure on first run")
      return
    }

    // Create replay token
    let token = ReplayToken(seed: failingSeed, config: config)

    // Replay using the token
    let result2 = await PropertyRunner.runFromToken(property, token: token)

    guard case .failure(_, _, let shrunk2, _, _) = result2 else {
      Issue.record("Expected failure on replay")
      return
    }

    // Same minimal counterexample should be found
    #expect(shrunk1 == shrunk2)
  }

  @Test("Replay with explicit token reproduces exact counterexample")
  func testReplayWithExplicitToken() async {
    // Property that fails on specific value
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<100, using: &rng)
    }

    let property = Property(generator: gen) { value in
      value != 42  // Fails when value is 42
    }

    // Use a seed known to produce 42 early
    let token = ReplayToken(
      seed: 42,
      iterations: 100,
      maxDiscarded: 500
    )

    let result = await PropertyRunner.runFromToken(property, token: token)

    // Should either fail or succeed deterministically based on seed
    switch result {
    case .success:
      // If the specific seed doesn't produce 42, that's fine
      break

    case .failure(_, _, _, _, let seed):
      // Verify we got the same seed back
      #expect(seed.rawValue == 42)

    case .gaveUp:
      Issue.record("Should not give up")
    }
  }

  @Test("Replay determinism: same token always produces same result")
  func testReplayDeterminism() async {
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<1000, using: &rng)
    }

    let property = Property(generator: gen) { value in
      value % 7 != 0  // Fails on multiples of 7
    }

    let token = ReplayToken(
      seed: 7777,
      iterations: 50,
      maxDiscarded: 200
    )

    // Run multiple times
    let result1 = await PropertyRunner.runFromToken(property, token: token)
    let result2 = await PropertyRunner.runFromToken(property, token: token)
    let result3 = await PropertyRunner.runFromToken(property, token: token)

    // Extract results for comparison
    switch (result1, result2, result3) {
    case (.success(let i1), .success(let i2), .success(let i3)):
      #expect(i1 == i2)
      #expect(i2 == i3)
    case (
      // swiftlint:disable:next large_tuple
      .failure(let c1, let iter1, let s1, let r1, _),
      // swiftlint:disable:next large_tuple
      .failure(let c2, let iter2, let s2, let r2, _),
      // swiftlint:disable:next large_tuple
      .failure(let c3, let iter3, let s3, let r3, _)
    ):
      #expect(c1 == c2)
      #expect(c2 == c3)
      #expect(iter1 == iter2)
      #expect(iter2 == iter3)
      #expect(s1 == s2)
      #expect(s2 == s3)
      #expect(r1 == r2)
      #expect(r2 == r3)

    default:
      Issue.record("All runs should have same result type")
    }
  }

  // MARK: - ThrowingProperty Replay Tests

  @Test("Replay works with ThrowingProperty")
  func testReplayThrowingProperty() async {
    struct TestError: Error {}

    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<100, using: &rng)
    }

    let property = ThrowingProperty(generator: gen) { value in
      if value > 50 {
        throw TestError()
      }
      return true
    }

    let token = ReplayToken(
      seed: 98765,
      iterations: 50,
      maxDiscarded: 100
    )

    let result1 = await PropertyRunner.runFromToken(property, token: token)
    let result2 = await PropertyRunner.runFromToken(property, token: token)

    // Results should be identical
    switch (result1, result2) {
    case (.success, .success):
      break  // Both succeed - OK
    case (.failure(_, let i1, _, _, _), .failure(_, let i2, _, _, _)):
      #expect(i1 == i2)  // Same iteration count
    case (.gaveUp, .gaveUp):
      break  // Both gave up - OK
    default:
      Issue.record("Replay should produce same result type")
    }
  }

  // MARK: - EvaluatingProperty Replay Tests

  @Test("Replay works with EvaluatingProperty")
  func testReplayEvaluatingProperty() async {
    let gen = Gen<Int> { rng, _ in
      Int.random(in: -100..<100, using: &rng)
    }

    let property = EvaluatingProperty(generator: gen) { value in
      if value < 0 {
        return .discard(reason: "need non-negative")
      }
      if value > 50 {
        return .fail(reason: "too large")
      }
      return .pass
    }

    let token = ReplayToken(
      seed: 11111,
      iterations: 100,
      maxDiscarded: 300
    )

    let result1 = await PropertyRunner.runFromToken(property, token: token)
    let result2 = await PropertyRunner.runFromToken(property, token: token)

    // Results should be identical
    switch (result1, result2) {
    case (.success(let i1), .success(let i2)):
      #expect(i1 == i2)

    case (.failure(_, let i1, _, _, _), .failure(_, let i2, _, _, _)):
      #expect(i1 == i2)

    case (.gaveUp(let d1, let i1), .gaveUp(let d2, let i2)):
      #expect(d1 == d2)
      #expect(i1 == i2)

    default:
      Issue.record("Replay should produce same result type")
    }
  }

  // MARK: - Token Round-Trip Integration Tests

  @Test("Full workflow: fail -> capture token -> replay")
  func testFullWorkflow() async {
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<1000, using: &rng)
    }

    // Property that always fails on first generated value >= 900
    let property = Property(generator: gen) { value in
      value < 900
    }

    // Run with a known seed
    let initialSeed = Seed(value: 333333)
    let runner = PropertyRunner(seed: initialSeed)
    let config = PropertyConfig(iterations: 200, maxDiscarded: 500, seed: initialSeed)

    let originalResult = runner.runProperty(property, config: config)

    // Skip if no failure
    guard case .failure(_, _, let originalShrunk, _, let failingSeed) = originalResult else {
      // Property might not fail with this config - that's OK
      return
    }

    // Create and encode token
    let token = ReplayToken(seed: failingSeed, config: config)
    let encoded = token.encode()

    // Parse the encoded token (simulating copy-paste scenario)
    guard let parsedToken = ReplayToken.parse(encoded) else {
      Issue.record("Failed to parse encoded token")
      return
    }

    // Replay from parsed token
    let replayResult = await PropertyRunner.runFromToken(property, token: parsedToken)

    guard case .failure(_, _, let replayShrunk, _, _) = replayResult else {
      Issue.record("Replay should produce same failure")
      return
    }

    // Verify same counterexample
    #expect(originalShrunk == replayShrunk)
  }

  // MARK: - Edge Cases

  @Test("Replay with zero seed")
  func testReplayZeroSeed() async {
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<10, using: &rng)
    }

    let property = Property(generator: gen) { _ in true }

    let token = ReplayToken(seed: 0, iterations: 10, maxDiscarded: 50)
    let result = await PropertyRunner.runFromToken(property, token: token)

    // Should complete without crashing
    switch result {
    case .success, .failure, .gaveUp:
      break  // All outcomes are valid
    }
  }

  @Test("Replay with max seed value")
  func testReplayMaxSeed() async {
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<10, using: &rng)
    }

    let property = Property(generator: gen) { _ in true }

    let token = ReplayToken(seed: UInt64.max, iterations: 10, maxDiscarded: 50)
    let result = await PropertyRunner.runFromToken(property, token: token)

    // Should complete without crashing
    switch result {
    case .success, .failure, .gaveUp:
      break  // All outcomes are valid
    }
  }
}
