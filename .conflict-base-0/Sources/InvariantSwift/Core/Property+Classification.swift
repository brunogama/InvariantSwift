import Foundation

// MARK: - Property Classification Extensions

extension Property {

  /// Add a coverage requirement to this property.
  ///
  /// Coverage checks verify that a certain percentage of test inputs satisfy a condition.
  /// This is useful for ensuring your property tests exercise diverse input spaces.
  ///
  /// When `enforceCoverage` is enabled in `PropertyConfig`, the property will fail
  /// if the coverage requirement isn't met across all iterations.
  ///
  /// - Parameters:
  ///   - percentage: Required minimum percentage (0-100) of iterations meeting the condition
  ///   - predicate: Condition that should be met for the required percentage of inputs
  ///   - label: Descriptive name for this coverage check
  ///
  /// - Returns: A `ClassifyingProperty` that tracks this coverage requirement
  ///
  /// - Example:
  ///   ```swift
  ///   Property(generator: Gen.int) { n in n >= 0 }
  ///     .cover(30, when: { $0 > 0 }, label: "positive")
  ///     .cover(10, when: { $0 == 0 }, label: "zero")
  ///   ```
  public func cover(
    _ percentage: Double,
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.cover(label, percentage: percentage) { predicate(value) }
      return self.predicate(value)
    }
  }

  /// Add a conditional classification label to this property.
  ///
  /// Classifications provide visibility into the distribution of test inputs.
  /// When the predicate is true, the label is recorded in the test report.
  ///
  /// Unlike `cover()`, classifications don't enforce thresholds - they simply
  /// report the distribution of labels across all iterations.
  ///
  /// - Parameters:
  ///   - predicate: Condition that determines when to apply this label
  ///   - label: The label to attach when the condition is met
  ///
  /// - Returns: A `ClassifyingProperty` that tracks this classification
  ///
  /// - Example:
  ///   ```swift
  ///   Property(generator: Gen.int) { n in n >= 0 }
  ///     .classify(when: { $0 > 0 }, label: "positive")
  ///     .classify(when: { $0 == 0 }, label: "zero")
  ///   ```
  public func classify(
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      if predicate(value) {
        ctx.classify("categories", label)
      }
      return self.predicate(value)
    }
  }

  /// Add an unconditional label to this property.
  ///
  /// Attaches a label to every test iteration. This is useful for:
  /// - Documenting what the property tests
  /// - Grouping related properties in test reports
  /// - Adding context to test failures
  ///
  /// - Parameter text: The label to attach to all iterations
  ///
  /// - Returns: A `ClassifyingProperty` with this label applied
  ///
  /// - Example:
  ///   ```swift
  ///   Property(generator: Gen.int) { n in n >= 0 }
  ///     .label("non-negative integers")
  ///   ```
  public func label(_ text: String) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.label(text)
      return self.predicate(value)
    }
  }
}
