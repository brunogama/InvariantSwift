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

  /// Collect arbitrary values and report histogram.
  ///
  /// Use `collect` to verify generator produces diverse values. Values are
  /// extracted via the closure and histogrammed for the classification report.
  ///
  /// - Parameter extract: Closure to extract the value to collect from input
  /// - Returns: ClassifyingProperty that tracks collected values
  ///
  /// - Example:
  ///   ```swift
  ///   Property(generator: Gen.array(Gen.int, count: 0...20)) { arr in
  ///     arr.sorted().count == arr.count
  ///   }
  ///   .collect { $0.count }  // Histogram array lengths
  ///   ```
  public func collect<U: CustomStringConvertible & Sendable>(
    _ extract: @escaping @Sendable (T) -> U
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      let extracted = extract(value)
      ctx.collect(extracted)
      return self.predicate(value)
    }
  }

  /// Collect numeric values with automatic bucketing for readability.
  public func collectBucketed<N: BinaryInteger & Sendable>(
    _ extract: @escaping @Sendable (T) -> N
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      let extracted = extract(value)
      ctx.collect(bucketNumeric(extracted))
      return self.predicate(value)
    }
  }
}

// MARK: - ClassifyingProperty Extensions

extension ClassifyingProperty {
  /// Add value collection to an existing classifying property.
  public func collect<U: CustomStringConvertible & Sendable>(
    _ extract: @escaping @Sendable (T) -> U
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      let extracted = extract(value)
      ctx.collect(extracted)
      return self.predicate(value, ctx)
    }
  }
}

// MARK: - Numeric Bucketing

/// Bucket numeric values into readable ranges for histogram display.
///
/// Prevents label explosion by grouping numbers into ranges:
/// - 0: "0"
/// - 1-9: "1-9"
/// - 10-99: "10-99"
/// - 100-999: "100-999"
/// - 1000+: "1000+"
///
/// Negative values are prefixed with "-" and bucketed by absolute value.
func bucketNumeric<N: BinaryInteger>(_ value: N) -> String {
  let absValue = abs(Int64(value))
  let prefix = value < 0 ? "-" : ""

  switch absValue {
  case 0: return "0"
  case 1..<10: return "\(prefix)1-9"
  case 10..<100: return "\(prefix)10-99"
  case 100..<1000: return "\(prefix)100-999"
  case 1000..<10000: return "\(prefix)1000-9999"
  default: return "\(prefix)10000+"
  }
}
