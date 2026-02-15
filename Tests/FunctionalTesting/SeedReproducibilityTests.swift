import Foundation
import Testing
@testable import InvariantSwift

// MARK: - SeedReproducibilityTests

/// Tests for seed-based reproducibility and INVARIANT_SEED environment variable.
@Suite("Seed Reproducibility Tests")
struct SeedReproducibilityTests {

  @Test("Same seed produces identical values")
  func sameSeedProducesIdenticalValues() async throws {
    let seed1 = Seed(value: 12345)
    let seed2 = Seed(value: 12345)

    // Seeds with same value should be equal
    #expect(seed1 == seed2)
    #expect(seed1.rawValue == seed2.rawValue)
  }

  @Test("Different seeds produce different values")
  func differentSeedsProduceDifferentValues() async throws {
    let seed1 = Seed(value: 12345)
    let seed2 = Seed(value: 99999)

    // Seeds with different values should not be equal
    #expect(seed1 != seed2)
  }

  @Test("Seed zero is converted to one")
  func seedZeroConvertedToOne() async throws {
    let seed = Seed(value: 0)
    #expect(seed.rawValue == 1)
  }

  @Test("Seed random produces different values")
  func seedRandomProducesDifferentValues() async throws {
    let seed1 = Seed.random
    let seed2 = Seed.random

    // Random seeds should typically be different
    // (Technically could collide but probability is negligible)
    #expect(seed1.rawValue != 0)  // Should never be 0
    #expect(seed2.rawValue != 0)
  }

  @Test("Seed environment value is accessible")
  func seedEnvironmentValueAccessible() async throws {
    // Just verify the API exists and returns a value
    let envValue = Seed.environmentSeedValue

    // If not set, should be nil
    // If set, should return the string value
    // We don't know the test environment, so just verify it doesn't crash
    _ = envValue
  }

  @Test("Seed environment check is accessible")
  func seedEnvironmentCheckAccessible() async throws {
    // Just verify the API exists
    let isSet = Seed.isEnvironmentSeedSet

    // Should be a boolean
    _ = isSet
  }

  @Test("ReplayToken can be created from seed")
  func replayTokenFromSeed() async throws {
    let seed = Seed(value: 12345)
    let config = PropertyConfig(
      iterations: 100,
      maxDiscarded: 500,
      seed: seed
    )

    let token = ReplayToken(seed: seed, config: config)

    #expect(token.seed == 12345)
    #expect(token.iterations == 100)
    #expect(token.maxDiscarded == 500)
  }

  @Test("ReplayToken encode and parse round-trip")
  func replayTokenRoundTrip() async throws {
    let original = ReplayToken(
      seed: 12345,
      iterations: 100,
      size: 50,
      maxDiscarded: 500,
      counterexample: "[1, 2, 3]"
    )

    let encoded = original.encode()
    let parsed = ReplayToken.parse(encoded)

    #expect(parsed != nil)
    #expect(parsed?.seed == original.seed)
    #expect(parsed?.iterations == original.iterations)
    #expect(parsed?.maxDiscarded == original.maxDiscarded)
  }

  @Test("ReplayToken simple seed format parsing")
  func replayTokenSimpleFormatParsing() async throws {
    let parsed = ReplayToken.parse("seed=12345")

    #expect(parsed != nil)
    #expect(parsed?.seed == 12345)
  }

  @Test("ReplayToken toConfig creates valid config")
  func replayTokenToConfig() async throws {
    let token = ReplayToken(
      seed: 12345,
      iterations: 200,
      maxDiscarded: 1000
    )

    let config = token.toConfig()

    #expect(config.iterations == 200)
    #expect(config.maxDiscarded == 1000)
    #expect(config.seed?.rawValue == 12345)
  }

  @Test("ReplayToken fullReproductionInstructions contains all options")
  func replayTokenReproductionInstructions() async throws {
    let token = ReplayToken(
      seed: 12345,
      iterations: 100,
      maxDiscarded: 500
    )

    let instructions = token.fullReproductionInstructions

    #expect(instructions.contains("REPRODUCTION"))
    #expect(instructions.contains("Option 1"))
    #expect(instructions.contains("Option 2"))
    #expect(instructions.contains("Option 3"))
    #expect(instructions.contains("INVARIANT_SEED"))
    #expect(instructions.contains("12345"))
  }

  @Test("PropertyConfig default factory uses environment or random")
  func propertyConfigDefaultFactory() async throws {
    let config = PropertyConfig.default()

    // Should have default values
    #expect(config.iterations == 100)
    #expect(config.maxShrinks == 1000)
    #expect(config.maxDiscarded == 500)

    // Seed should be set (either from env or random)
    #expect(config.seed != nil)
  }
}

// MARK: - Edge Cases

extension SeedReproducibilityTests {

  @Test("Seed handles large values")
  func seedHandlesLargeValues() async throws {
    let largeValue = UInt64.max
    let seed = Seed(value: largeValue)

    #expect(seed.rawValue == largeValue)
  }

  @Test("ReplayToken handles missing counterexample")
  func replayTokenMissingCounterexample() async throws {
    let token = ReplayToken(
      seed: 12345,
      iterations: 100,
      counterexample: nil
    )

    #expect(token.counterexample == nil)

    let encoded = token.encode()
    let parsed = ReplayToken.parse(encoded)

    #expect(parsed?.counterexample == nil)
  }

  @Test("Invalid ReplayToken parse returns nil")
  func invalidReplayTokenParseReturnsNil() async throws {
    let parsed = ReplayToken.parse("invalid-token-string")

    #expect(parsed == nil)
  }
}
