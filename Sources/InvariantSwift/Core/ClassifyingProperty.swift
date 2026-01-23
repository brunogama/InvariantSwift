import Foundation

// MARK: - Classifying Property

/// A property that supports inline classification and coverage tracking.
///
/// `ClassifyingProperty` extends the standard `Property` with a `ClassificationContext`
/// parameter in the predicate, enabling inline labeling and coverage requirements.
///
/// **Use Cases:**
/// - Verify test inputs cover different categories (positive/negative, small/large)
/// - Ensure boundary values are tested with minimum frequency
/// - Diagnose when generators produce skewed distributions
///
/// - Example:
///   ```swift
///   let property = ClassifyingProperty(generator: Gen.int(in: -100...100)) { n, ctx in
///       // Classify by sign
///       ctx.classify("sign", n < 0 ? "negative" : n > 0 ? "positive" : "zero")
///
///       // Ensure at least 5% are extreme values
///       ctx.cover("extremes", percentage: 5.0) { abs(n) > 90 }
///
///       // The actual property check
///       return n + 0 == n
///   }
///
///   let runner = PropertyRunner()
///   let result = runner.runClassifyingProperty(property)
///   // Result includes classification report with label distributions
///   ```
///
/// - See Also: ``ClassificationContext``, ``ClassificationReport``, ``Property``
public struct ClassifyingProperty<T: Sendable>: @unchecked Sendable {

  /// The generator producing test values for this property.
  public let generator: Gen<T>

  /// The assumption (precondition) that filters valid test cases.
  ///
  /// If a generated value doesn't satisfy the assumption, it is discarded.
  /// Classifications are NOT recorded for discarded values.
  public let assumption: @Sendable (T) -> Bool

  /// The predicate with classification context.
  ///
  /// The context parameter enables inline classification via `classify` and `cover`.
  public let predicate: @Sendable (T, ClassificationContext) -> Bool

  /// Initialize a classifying property with a generator and predicate.
  ///
  /// - Parameters:
  ///   - generator: Values to test
  ///   - assumption: Filter for valid values (default: all valid)
  ///   - predicate: Condition that must hold true, with classification context
  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T, ClassificationContext) -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Throwing Classifying Property

/// A classifying property that can throw errors during execution.
///
/// Combines classification support with throwing predicates.
public struct ThrowingClassifyingProperty<T: Sendable>: @unchecked Sendable {

  /// The generator producing test values for this property.
  public let generator: Gen<T>

  /// The assumption (precondition) that filters valid test cases.
  public let assumption: @Sendable (T) -> Bool

  /// The predicate that must hold true (or not throw), with classification context.
  public let predicate: @Sendable (T, ClassificationContext) throws -> Bool

  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T, ClassificationContext) throws -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Evaluating Classifying Property

/// A classifying property that returns explicit evaluation results.
///
/// Combines classification support with explicit pass/fail/discard outcomes.
public struct EvaluatingClassifyingProperty<T: Sendable>: @unchecked Sendable {

  /// The generator producing test values for this property.
  public let generator: Gen<T>

  /// The predicate returning explicit evaluation outcomes, with classification context.
  public let evaluate: @Sendable (T, ClassificationContext) -> PropertyEvaluation

  public init(
    generator: Gen<T>,
    evaluate: @escaping @Sendable (T, ClassificationContext) -> PropertyEvaluation
  ) {
    self.generator = generator
    self.evaluate = evaluate
  }
}

// MARK: - Convenience Initializers

extension ClassifyingProperty {

  /// Create a classifying property from a standard property by adding a no-op context.
  ///
  /// Useful for running standard properties through the classifying runner
  /// when you want to add classification later.
  public init(from property: Property<T>) {
    self.generator = property.generator
    self.assumption = property.assumption
    self.predicate = { value, _ in property.predicate(value) }
  }
}

extension Property {

  /// Create a classifying property from this property.
  ///
  /// The resulting property ignores the classification context but can be
  /// run through `runClassifyingProperty` to get structured results.
  public func withClassification(
    _ classify: @escaping @Sendable (T, ClassificationContext) -> Void
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: generator,
      assumption: assumption
    ) { value, ctx in
      classify(value, ctx)
      return self.predicate(value)
    }
  }
}
