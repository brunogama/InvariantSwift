import Foundation

// MARK: - Classifying Property Result

/// Result of running a classifying property, combining the base result with classification data.
///
/// This type provides a non-breaking way to add classification reporting to property testing
/// results without modifying the existing `PropertyResult` enum.
///
/// - See Also: ``ClassifyingProperty``, ``ClassificationReport``
public struct ClassifyingPropertyResult<T: Sendable>: Sendable {

  /// The underlying property result (success, failure, or gaveUp).
  public let result: PropertyResult<T>

  /// Classification report from the test run.
  public let classification: ClassificationReport

  /// Whether all coverage thresholds were met.
  public var coverageThresholdsMet: Bool {
    classification.allCoverageThresholdsMet
  }

  public init(result: PropertyResult<T>, classification: ClassificationReport) {
    self.result = result
    self.classification = classification
  }
}

// MARK: - PropertyRunner Extensions for Classifying Properties

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PropertyRunner {

  // MARK: - Classifying Property Runner

  /// Run a classifying property test with inline classification tracking.
  ///
  /// Executes the property while collecting classification data from `classify` and `cover`
  /// calls made in the property body. Returns both the test result and classification report.
  ///
  /// - Parameters:
  ///   - property: The classifying property to test
  ///   - config: Configuration controlling iterations and shrinking
  ///   - enforceCoverageThresholds: If true, fail the test when coverage thresholds are unmet
  ///
  /// - Returns: Combined result with property outcome and classification report
  ///
  /// - Example:
  ///   ```swift
  ///   let property = ClassifyingProperty(generator: Gen.int(in: -100...100)) { n, ctx in
  ///       ctx.classify("sign", n < 0 ? "negative" : "positive")
  ///       ctx.cover("extremes", percentage: 5.0) { abs(n) > 90 }
  ///       return n + 0 == n
  ///   }
  ///
  ///   let result = runner.runClassifyingProperty(property)
  ///   print(result.classification.format())
  ///   ```
  public func runClassifyingProperty<T>(
    _ property: ClassifyingProperty<T>,
    config: PropertyConfig = .default,
    enforceCoverageThresholds: Bool = false
  ) -> ClassifyingPropertyResult<T> {
    let context = ClassificationContext()
    var discarded = 0
    var successfulIterations = 0

    // Use the actor's RNG state
    var localRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: seed)

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&localRng, size)
      let testCase = tree.value

      // Check assumption first - discarded values never reach the predicate
      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          let report = context.report()
          return ClassifyingPropertyResult(
            result: .gaveUp(discarded: discarded, iterations: successfulIterations),
            classification: report
          )
        }
        continue
      }

      // Record this iteration and evaluate the property
      context.recordIteration()
      let passed = property.predicate(testCase, context)

      if !passed {
        // Property failed - shrink using the pre-built tree
        let shrunkCase = shrinkClassifyingFailureWithTree(
          tree,
          property: property,
          context: context,
          maxShrinks: config.maxShrinks
        )

        let report = context.report()
        return ClassifyingPropertyResult(
          result: .failure(
            counterexample: testCase,
            iterations: successfulIterations + 1,
            shrunk: shrunkCase,
            reason: .predicateFailed,
            seed: seed
          ),
          classification: report
        )
      }

      successfulIterations += 1
    }

    // All iterations passed
    let report = context.report()

    // Check coverage thresholds if enforcement is enabled
    if enforceCoverageThresholds {
      let unmet = report.unmetCoverageChecks
      if !unmet.isEmpty {
        // Treat unmet coverage as a property failure
        return ClassifyingPropertyResult(
          result: .failure(
            counterexample: property.generator.sample(size: Size(value: 50), seed: seed),
            iterations: successfulIterations,
            shrunk: property.generator.sample(size: Size(value: 50), seed: seed),
            reason: .threwError("Coverage thresholds unmet: \(unmet.joined(separator: ", "))"),
            seed: seed
          ),
          classification: report
        )
      }
    }

    return ClassifyingPropertyResult(
      result: .success(iterations: successfulIterations),
      classification: report
    )
  }

  // MARK: - Throwing Classifying Property Runner

  /// Run a throwing classifying property test.
  ///
  /// - Parameters:
  ///   - property: The throwing classifying property to test
  ///   - config: Configuration controlling iterations and shrinking
  ///   - enforceCoverageThresholds: If true, fail the test when coverage thresholds are unmet
  ///
  /// - Returns: Combined result with property outcome and classification report
  public func runThrowingClassifyingProperty<T>(
    _ property: ThrowingClassifyingProperty<T>,
    config: PropertyConfig = .default,
    enforceCoverageThresholds: Bool = false
  ) -> ClassifyingPropertyResult<T> {
    let context = ClassificationContext()
    var discarded = 0
    var successfulIterations = 0

    var localRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: seed)

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&localRng, size)
      let testCase = tree.value

      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          let report = context.report()
          return ClassifyingPropertyResult(
            result: .gaveUp(discarded: discarded, iterations: successfulIterations),
            classification: report
          )
        }
        continue
      }

      context.recordIteration()

      do {
        let passed = try property.predicate(testCase, context)
        if !passed {
          let shrunkCase = shrinkThrowingClassifyingFailureWithTree(
            tree,
            property: property,
            context: context,
            maxShrinks: config.maxShrinks
          )

          let report = context.report()
          return ClassifyingPropertyResult(
            result: .failure(
              counterexample: testCase,
              iterations: successfulIterations + 1,
              shrunk: shrunkCase,
              reason: .predicateFailed,
              seed: seed
            ),
            classification: report
          )
        }
      } catch {
        let shrunkCase = shrinkThrowingClassifyingFailureWithTree(
          tree,
          property: property,
          context: context,
          maxShrinks: config.maxShrinks
        )

        let report = context.report()
        return ClassifyingPropertyResult(
          result: .failure(
            counterexample: testCase,
            iterations: successfulIterations + 1,
            shrunk: shrunkCase,
            reason: .threwError(String(describing: error)),
            seed: seed
          ),
          classification: report
        )
      }

      successfulIterations += 1
    }

    let report = context.report()

    if enforceCoverageThresholds {
      let unmet = report.unmetCoverageChecks
      if !unmet.isEmpty {
        return ClassifyingPropertyResult(
          result: .failure(
            counterexample: property.generator.sample(size: Size(value: 50), seed: seed),
            iterations: successfulIterations,
            shrunk: property.generator.sample(size: Size(value: 50), seed: seed),
            reason: .threwError("Coverage thresholds unmet: \(unmet.joined(separator: ", "))"),
            seed: seed
          ),
          classification: report
        )
      }
    }

    return ClassifyingPropertyResult(
      result: .success(iterations: successfulIterations),
      classification: report
    )
  }

  // MARK: - Evaluating Classifying Property Runner

  /// Run an evaluating classifying property test.
  ///
  /// - Parameters:
  ///   - property: The evaluating classifying property to test
  ///   - config: Configuration controlling iterations and shrinking
  ///   - enforceCoverageThresholds: If true, fail the test when coverage thresholds are unmet
  ///
  /// - Returns: Combined result with property outcome and classification report
  public func runEvaluatingClassifyingProperty<T>(
    _ property: EvaluatingClassifyingProperty<T>,
    config: PropertyConfig = .default,
    enforceCoverageThresholds: Bool = false
  ) -> ClassifyingPropertyResult<T> {
    let context = ClassificationContext()
    var discarded = 0
    var successfulIterations = 0

    var localRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: seed)

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&localRng, size)
      let testCase = tree.value

      context.recordIteration()
      let evaluation = property.evaluate(testCase, context)

      switch evaluation {
      case .pass:
        successfulIterations += 1

      case .discard:
        discarded += 1
        if discarded > config.maxDiscarded {
          let report = context.report()
          return ClassifyingPropertyResult(
            result: .gaveUp(discarded: discarded, iterations: successfulIterations),
            classification: report
          )
        }

      case .fail(let reason):
        let shrunkCase = shrinkEvaluatingClassifyingFailureWithTree(
          tree,
          property: property,
          context: context,
          maxShrinks: config.maxShrinks
        )

        let failureReason: FailureReason = reason.map { .threwError($0) } ?? .predicateFailed
        let report = context.report()
        return ClassifyingPropertyResult(
          result: .failure(
            counterexample: testCase,
            iterations: successfulIterations + 1,
            shrunk: shrunkCase,
            reason: failureReason,
            seed: seed
          ),
          classification: report
        )
      }
    }

    let report = context.report()

    if enforceCoverageThresholds {
      let unmet = report.unmetCoverageChecks
      if !unmet.isEmpty {
        return ClassifyingPropertyResult(
          result: .failure(
            counterexample: property.generator.sample(size: Size(value: 50), seed: seed),
            iterations: successfulIterations,
            shrunk: property.generator.sample(size: Size(value: 50), seed: seed),
            reason: .threwError("Coverage thresholds unmet: \(unmet.joined(separator: ", "))"),
            seed: seed
          ),
          classification: report
        )
      }
    }

    return ClassifyingPropertyResult(
      result: .success(iterations: successfulIterations),
      classification: report
    )
  }

  // MARK: - Private Shrinking Helpers

  /// Shrink a classifying property failure using a pre-built shrink tree.
  private func shrinkClassifyingFailureWithTree<T>(
    _ tree: ShrinkTree<T>,
    property: ClassifyingProperty<T>,
    context: ClassificationContext,
    maxShrinks: Int
  ) -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      // Use a fresh context for shrinking (don't pollute main stats)
      let shrinkContext = ClassificationContext()
      return !property.predicate(candidate, shrinkContext)
    }

    return minimal ?? tree.value
  }

  /// Shrink a throwing classifying property failure using a pre-built shrink tree.
  private func shrinkThrowingClassifyingFailureWithTree<T>(
    _ tree: ShrinkTree<T>,
    property: ThrowingClassifyingProperty<T>,
    context: ClassificationContext,
    maxShrinks: Int
  ) -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      let shrinkContext = ClassificationContext()
      do {
        return try !property.predicate(candidate, shrinkContext)
      } catch {
        return true
      }
    }

    return minimal ?? tree.value
  }

  /// Shrink an evaluating classifying property failure using a pre-built shrink tree.
  private func shrinkEvaluatingClassifyingFailureWithTree<T>(
    _ tree: ShrinkTree<T>,
    property: EvaluatingClassifyingProperty<T>,
    context: ClassificationContext,
    maxShrinks: Int
  ) -> T {
    let filteredTree = tree.filter { candidate in
      let shrinkContext = ClassificationContext()
      if case .discard = property.evaluate(candidate, shrinkContext) {
        return false
      }
      return true
    }

    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      let shrinkContext = ClassificationContext()
      if case .fail = property.evaluate(candidate, shrinkContext) {
        return true
      }
      return false
    }

    return minimal ?? tree.value
  }
}
