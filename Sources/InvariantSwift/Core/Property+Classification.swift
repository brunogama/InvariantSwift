import Foundation

// MARK: - Property Classification Extensions
//
// This file provides fluent API extensions for property classification and observation:
//
// - **classify**: Single boolean condition -> single label (e.g., "45% positive")
// - **tabulate**: Multiple labels per input -> multi-dimensional analysis
// - **cover**: Enforce minimum percentage coverage for conditions
// - **label**: Unconditional labeling of all test cases
// - **collect**: Histogram tracking of extracted values
//
// Use `classify` for binary categories (true/false conditions).
// Use `tabulate` for value distributions and multi-dimensional correlations.

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

  /// Add a conditional classification label in a specific category.
  public func classify(
    _ category: String,
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      if predicate(value) {
        ctx.classify(category, label)
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

  /// Attach a dynamic label computed from the input.
  public func label(_ compute: @escaping @Sendable (T) -> String) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.label(compute(value))
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

  // MARK: - Multi-Dimensional Tabulation

  /// Track multiple independent classification categories.
  ///
  /// Use `tabulate` to analyze correlations across dimensions. Unlike `classify`,
  /// tabulate allows multiple labels per input within a category.
  ///
  /// - Parameters:
  ///   - category: Category name for this dimension (e.g., "magnitude", "sign")
  ///   - labels: Closure returning array of labels for this input
  ///
  /// - Returns: ClassifyingProperty that tracks the tabulation
  ///
  /// - Example:
  ///   ```swift
  ///   Property(generator: Gen.int) { n in abs(n) >= 0 }
  ///     .tabulate("magnitude") { n in
  ///       [abs(n) < 10 ? "small" : "large"]
  ///     }
  ///     .tabulate("sign") { n in
  ///       [n > 0 ? "positive" : n < 0 ? "negative" : "zero"]
  ///     }
  ///   ```
  public func tabulate(
    _ category: String,
    labels: @escaping @Sendable (T) -> [String]
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.tabulate(category, labels: labels(value))
      return self.predicate(value)
    }
  }

  /// Convenience for single-label tabulation.
  public func tabulate(
    _ category: String,
    label: @escaping @Sendable (T) -> String
  ) -> ClassifyingProperty<T> {
    tabulate(category, labels: { [label($0)] })
  }
}

// MARK: - ClassifyingProperty Extensions

extension ClassifyingProperty {
  /// Add coverage check to existing classifying property.
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
      return self.predicate(value, ctx)
    }
  }

  /// Add classification to existing classifying property.
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
      return self.predicate(value, ctx)
    }
  }

  /// Add classification in a specific category.
  public func classify(
    _ category: String,
    when predicate: @escaping @Sendable (T) -> Bool,
    label: String
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      if predicate(value) {
        ctx.classify(category, label)
      }
      return self.predicate(value, ctx)
    }
  }

  /// Add static label to existing classifying property.
  public func label(_ text: String) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.label(text)
      return self.predicate(value, ctx)
    }
  }

  /// Add dynamic label to existing classifying property.
  public func label(_ compute: @escaping @Sendable (T) -> String) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.label(compute(value))
      return self.predicate(value, ctx)
    }
  }

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

  /// Add tabulation to an existing classifying property.
  public func tabulate(
    _ category: String,
    labels: @escaping @Sendable (T) -> [String]
  ) -> ClassifyingProperty<T> {
    ClassifyingProperty(
      generator: self.generator,
      assumption: self.assumption
    ) { value, ctx in
      ctx.tabulate(category, labels: labels(value))
      return self.predicate(value, ctx)
    }
  }

  /// Convenience for single-label tabulation.
  public func tabulate(
    _ category: String,
    label: @escaping @Sendable (T) -> String
  ) -> ClassifyingProperty<T> {
    tabulate(category, labels: { [label($0)] })
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
