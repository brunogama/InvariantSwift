import InvariantSwiftCore
import Testing

private let regressionBank = RegressionBank()
private let failingExampleDatabase = FailingExampleDatabase(backend: .memory)
private let testIdentifier = TestIdentifier(
  module: "InvariantSwiftTesting",
  file: "PropertyConfigDerivationTests.swift",
  function: "derivedConfiguration",
  signature: "(Int)"
)
private let nonDefaultConfiguration = PropertyConfig(
  iterations: 345,
  maxShrinks: 678,
  maxDiscarded: 901,
  seed: Seed(value: 123),
  verbose: true,
  timeout: 4.5,
  verbosity: .silent,
  regressionBank: regressionBank,
  propertyId: "PropertyConfigDerivationTests",
  failingExampleDatabase: failingExampleDatabase,
  testIdentifier: testIdentifier,
  replayFirst: true,
  maxReplayExamples: 12,
  unicodeMode: .asciiOnly,
  maxStringShrinkSteps: 234,
  coverage: .init(
    enforceCoverage: false,
    warnOnLowCoverage: false,
    maxLabels: 56
  ),
  discard: .init(warnRatio: 7.5, failRatio: 9.5, enforceRatio: false),
  showProgress: true,
  progressInterval: .seconds(6.5)
)

@Suite("Property Config Derivation Tests")
struct PropertyConfigDerivationTests {
  @Test("execution seed derivation preserves other configuration fields")
  func executionSeedDerivationPreservesConfiguration() {
    let executionSeed = Seed(value: 456)
    let derived = nonDefaultConfiguration.withExecutionSeed(executionSeed)

    #expect(derived.seed == executionSeed)
    expectExecutionConfiguration(
      toMatch: nonDefaultConfiguration,
      derived: derived
    )
  }

  @Test("replay derivation clears persistence, keeps execution settings")
  func replayConfigurationRetainsExecutionSettings() {
    let replaySeed = Seed(value: 789)
    let derived = nonDefaultConfiguration.replayConfiguration(
      seed: replaySeed,
      minimumIterations: 400
    )

    #expect(derived.iterations == 400)
    #expect(derived.seed == replaySeed)
    #expect(derived.regressionBank == nil)
    #expect(derived.propertyId == nil)
    #expect(derived.failingExampleDatabase == nil)
    #expect(derived.testIdentifier == nil)
    #expect(derived.replayFirst == false)
    #expect(derived.maxReplayExamples == nil)
    expectReplayConfiguration(
      toMatch: nonDefaultConfiguration,
      derived: derived
    )
  }
}

private func expectExecutionConfiguration(
  toMatch source: PropertyConfig,
  derived: PropertyConfig
) {
  #expect(derived.iterations == source.iterations)
  #expect(derived.maxShrinks == source.maxShrinks)
  #expect(derived.maxDiscarded == source.maxDiscarded)
  #expect(derived.verbose == source.verbose)
  #expect(derived.timeout == source.timeout)
  #expect(sameVerbosity(derived.verbosity, source.verbosity))
  #expect(derived.regressionBank === source.regressionBank)
  #expect(derived.propertyId == source.propertyId)
  #expect(derived.failingExampleDatabase === source.failingExampleDatabase)
  #expect(derived.testIdentifier == source.testIdentifier)
  #expect(derived.replayFirst == source.replayFirst)
  #expect(derived.maxReplayExamples == source.maxReplayExamples)
  #expect(sameUnicodeMode(derived.unicodeMode, source.unicodeMode))
  #expect(derived.maxStringShrinkSteps == source.maxStringShrinkSteps)
  #expect(derived.coverage == source.coverage)
  #expect(derived.discard == source.discard)
  #expect(derived.showProgress == source.showProgress)
  #expect(derived.progressInterval == source.progressInterval)
}

private func expectReplayConfiguration(
  toMatch source: PropertyConfig,
  derived: PropertyConfig
) {
  #expect(derived.maxShrinks == source.maxShrinks)
  #expect(derived.maxDiscarded == source.maxDiscarded)
  #expect(derived.verbose == source.verbose)
  #expect(derived.timeout == source.timeout)
  #expect(sameVerbosity(derived.verbosity, source.verbosity))
  #expect(sameUnicodeMode(derived.unicodeMode, source.unicodeMode))
  #expect(derived.maxStringShrinkSteps == source.maxStringShrinkSteps)
  #expect(derived.coverage == source.coverage)
  #expect(derived.discard == source.discard)
  #expect(derived.showProgress == source.showProgress)
  #expect(derived.progressInterval == source.progressInterval)
}

private func sameVerbosity(
  _ left: PropertyConfig.Verbosity,
  _ right: PropertyConfig.Verbosity
) -> Bool {
  switch (left, right) {
  case (.silent, .silent), (.normal, .normal), (.verbose, .verbose):
    true

  default:
    false
  }
}

private func sameUnicodeMode(
  _ left: PropertyConfig.UnicodeMode,
  _ right: PropertyConfig.UnicodeMode
) -> Bool {
  switch (left, right) {
  case (.scalarSafe, .scalarSafe), (.asciiOnly, .asciiOnly):
    true

  default:
    false
  }
}
