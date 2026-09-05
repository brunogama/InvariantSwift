/// Focused derivation seams owned by `PropertyConfig`.
///
/// Execution and replay flows need configurations that differ from a base
/// configuration only in the seed, iteration floor, and persistence fields.
/// `PropertyConfig` owns these derivations so callers never reconstruct the
/// full field set externally and cannot drift when fields are added.
extension PropertyConfig {
  /// Returns a configuration identical to `self` with `seed` as the
  /// execution seed.
  ///
  /// Every other field is preserved unchanged.
  ///
  /// - Parameter seed: The resolved seed the run executes with.
  /// - Returns: A configuration equal to `self` except for `seed`.
  package func withExecutionSeed(_ seed: Seed) -> Self {
    var derivation = ConfigurationDerivation(base: self)
    derivation.seed = seed
    return derivation.built
  }

  /// Returns a deterministic replay configuration derived from `self`.
  ///
  /// The derived configuration replays a previously observed failure:
  /// - `seed` becomes the recorded failure seed.
  /// - `iterations` is raised to at least `minimumIterations` so the
  ///   failing iteration is reachable.
  /// - Persistence and replay bookkeeping are cleared (`regressionBank`,
  ///   `propertyId`, `failingExampleDatabase`, `testIdentifier`,
  ///   `maxReplayExamples` become `nil`; `replayFirst` becomes `false`)
  ///   so the replay itself never re-persists or re-replays.
  ///
  /// All remaining execution settings are preserved unchanged.
  ///
  /// - Parameters:
  ///   - seed: The recorded seed that reproduced the failure.
  ///   - minimumIterations: The iteration count needed to reach the failure.
  /// - Returns: A configuration for deterministically replaying the failure.
  package func replayConfiguration(seed: Seed, minimumIterations: Int) -> Self {
    var derivation = ConfigurationDerivation(base: self)
    derivation.seed = seed
    derivation.iterations = max(iterations, minimumIterations)
    derivation.clearsPersistence = true
    return derivation.built
  }
}

/// Mutable builder over the derivable `PropertyConfig` fields.
///
/// The builder owns the single call site that reconstructs the full
/// `PropertyConfig` field set, so each derivation seam only states the
/// fields it overrides.
private struct ConfigurationDerivation {
  let base: PropertyConfig
  var seed: Seed?
  var iterations: Int
  var clearsPersistence = false

  init(base: PropertyConfig) {
    self.base = base
    seed = base.seed
    iterations = base.iterations
  }

  var built: PropertyConfig {
    let bank = clearsPersistence ? nil : base.regressionBank
    let propertyId = clearsPersistence ? nil : base.propertyId
    let database = clearsPersistence ? nil : base.failingExampleDatabase
    let identifier = clearsPersistence ? nil : base.testIdentifier
    let replayFirst = clearsPersistence ? false : base.replayFirst
    let maxReplayExamples = clearsPersistence ? nil : base.maxReplayExamples
    return PropertyConfig(
      iterations: iterations,
      maxShrinks: base.maxShrinks,
      maxDiscarded: base.maxDiscarded,
      seed: seed,
      verbose: base.verbose,
      timeout: base.timeout,
      verbosity: base.verbosity,
      regressionBank: bank,
      propertyId: propertyId,
      failingExampleDatabase: database,
      testIdentifier: identifier,
      replayFirst: replayFirst,
      maxReplayExamples: maxReplayExamples,
      unicodeMode: base.unicodeMode,
      maxStringShrinkSteps: base.maxStringShrinkSteps,
      coverage: base.coverage,
      discard: base.discard,
      showProgress: base.showProgress,
      progressInterval: base.progressInterval
    )
  }
}
