import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

/// Tests for `ReplayToken` - deterministic failure reproduction tokens.
@Suite("Replay Token Tests")
struct ReplayTokenTests {

  // MARK: - Initialization Tests

  @Test("Initialize with seed only uses defaults")
  func testInitWithSeedOnly() {
    let token = ReplayToken(seed: 12345)

    #expect(token.seed == 12345)
    #expect(token.iterations == 100)  // Default
    #expect(token.size == 100)  // Default
    #expect(token.maxDiscarded == 500)  // Default
    #expect(token.counterexample == nil)
  }

  @Test("Initialize with all parameters")
  func testInitWithAllParameters() {
    let token = ReplayToken(
      seed: 98765,
      iterations: 50,
      size: 25,
      maxDiscarded: 200,
      counterexample: "[1, 2, 3]"
    )

    #expect(token.seed == 98765)
    #expect(token.iterations == 50)
    #expect(token.size == 25)
    #expect(token.maxDiscarded == 200)
    #expect(token.counterexample == "[1, 2, 3]")
  }

  @Test("Initialize from Seed and PropertyConfig")
  func testInitFromSeedAndConfig() {
    let seed = Seed(value: 42)
    let config = PropertyConfig(
      iterations: 200,
      maxShrinks: 1000,
      maxDiscarded: 300
    )

    let token = ReplayToken(seed: seed, config: config)

    #expect(token.seed == 42)
    #expect(token.iterations == 200)
    #expect(token.maxDiscarded == 300)
  }

  // MARK: - Encoding Tests

  @Test("Encode produces base64url string")
  func testEncode() {
    let token = ReplayToken(seed: 42)
    let encoded = token.encode()

    // Should be a non-empty base64url string (no +, /, or = padding)
    #expect(!encoded.isEmpty)
    #expect(!encoded.contains("+"))
    #expect(!encoded.contains("/"))
    #expect(!encoded.contains("="))
  }

  @Test("Round-trip encoding preserves all values")
  func testRoundTrip() {
    let original = ReplayToken(
      seed: 999999,
      iterations: 500,
      size: 75,
      maxDiscarded: 1000,
      counterexample: "test value"
    )

    let encoded = original.encode()
    let parsed = ReplayToken.parse(encoded)

    #expect(parsed != nil)
    #expect(parsed?.seed == original.seed)
    #expect(parsed?.iterations == original.iterations)
    #expect(parsed?.size == original.size)
    #expect(parsed?.maxDiscarded == original.maxDiscarded)
    #expect(parsed?.counterexample == original.counterexample)
  }

  @Test("Round-trip with nil counterexample")
  func testRoundTripNilCounterexample() {
    let original = ReplayToken(seed: 123, counterexample: nil)

    let encoded = original.encode()
    let parsed = ReplayToken.parse(encoded)

    #expect(parsed != nil)
    #expect(parsed?.counterexample == nil)
  }

  // MARK: - Parsing Tests

  @Test("Parse simple seed format")
  func testParseSimpleFormat() {
    let parsed = ReplayToken.parse("seed=12345")

    #expect(parsed != nil)
    #expect(parsed?.seed == 12345)
    #expect(parsed?.iterations == 100)  // Uses defaults
  }

  @Test("Parse handles large seed values")
  func testParseLargeSeed() {
    let largeSeed: UInt64 = 18_446_744_073_709_551_615  // UInt64.max
    let token = ReplayToken(seed: largeSeed)
    let encoded = token.encode()
    let parsed = ReplayToken.parse(encoded)

    #expect(parsed?.seed == largeSeed)
  }

  @Test("Parse zero seed")
  func testParseZeroSeed() {
    let token = ReplayToken(seed: 0)
    let encoded = token.encode()
    let parsed = ReplayToken.parse(encoded)

    #expect(parsed?.seed == 0)
  }

  @Test("Parse invalid string returns nil")
  func testParseInvalid() {
    #expect(ReplayToken.parse("garbage") == nil)
    #expect(ReplayToken.parse("seed=notanumber") == nil)
    #expect(ReplayToken.parse("") == nil)
  }

  // MARK: - toConfig Tests

  @Test("toConfig produces valid PropertyConfig")
  func testToConfig() {
    let token = ReplayToken(
      seed: 54321,
      iterations: 250,
      size: 50,
      maxDiscarded: 400
    )

    let config = token.toConfig()

    #expect(config.iterations == 250)
    #expect(config.maxDiscarded == 400)
    #expect(config.seed?.rawValue == 54321)
    #expect(config.maxShrinks == 1000)  // Default shrink budget
  }

  @Test("toConfig with seed only")
  func testToConfigWithSeedOnly() {
    let token = ReplayToken(seed: 42)
    let config = token.toConfig()

    #expect(config.seed?.rawValue == 42)
    #expect(config.iterations == 100)
    #expect(config.maxDiscarded == 500)
  }

  // MARK: - Factory Method Tests

  @Test("from creates token for failure result")
  func testFromFailureResult() {
    let result: PropertyResult<Int> = .failure(
      counterexample: 999,
      iterations: 50,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 7777)
    )

    let config = PropertyConfig(iterations: 100, maxDiscarded: 500)
    let token = ReplayToken.from(result, config: config)

    #expect(token != nil)
    #expect(token?.seed == 7777)
    #expect(token?.iterations == 100)
    #expect(token?.maxDiscarded == 500)
  }

  @Test("from returns nil for success result")
  func testFromSuccessResult() {
    let result: PropertyResult<Int> = .success(iterations: 100)
    let config = PropertyConfig()
    let token = ReplayToken.from(result, config: config)

    #expect(token == nil)
  }

  @Test("from returns nil for gaveUp result")
  func testFromGaveUpResult() {
    let result: PropertyResult<Int> = .gaveUp(discarded: 501, iterations: 99)
    let config = PropertyConfig()
    let token = ReplayToken.from(result, config: config)

    #expect(token == nil)
  }

  // MARK: - Description and Snippet Tests

  @Test("description includes all values")
  func testDescription() {
    let token = ReplayToken(
      seed: 123,
      iterations: 50,
      size: 25,
      maxDiscarded: 100,
      counterexample: "test"
    )

    let desc = token.description

    #expect(desc.contains("seed: 123"))
    #expect(desc.contains("iterations: 50"))
    #expect(desc.contains("maxDiscarded: 100"))
    #expect(desc.contains("counterexample: test"))
  }

  @Test("replaySnippet produces valid Swift code")
  func testReplaySnippet() {
    let token = ReplayToken(
      seed: 42,
      iterations: 100,
      maxDiscarded: 500
    )

    let snippet = token.replaySnippet

    #expect(snippet.contains("PropertyConfig"))
    #expect(snippet.contains("iterations: 100"))
    #expect(snippet.contains("maxDiscarded: 500"))
    #expect(snippet.contains("Seed(value: 42)"))
  }

  // MARK: - Equatable Tests

  @Test("Equal tokens are equal")
  func testEquality() {
    let token1 = ReplayToken(seed: 42, iterations: 100, size: 50, maxDiscarded: 500)
    let token2 = ReplayToken(seed: 42, iterations: 100, size: 50, maxDiscarded: 500)

    #expect(token1 == token2)
  }

  @Test("Different tokens are not equal")
  func testInequality() {
    let token1 = ReplayToken(seed: 42)
    let token2 = ReplayToken(seed: 43)

    #expect(token1 != token2)
  }

  // MARK: - Codable Tests

  @Test("Token is JSON encodable and decodable")
  func testCodable() throws {
    let original = ReplayToken(
      seed: 12345,
      iterations: 200,
      size: 75,
      maxDiscarded: 300,
      counterexample: "example"
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(ReplayToken.self, from: data)

    #expect(decoded == original)
  }
}
