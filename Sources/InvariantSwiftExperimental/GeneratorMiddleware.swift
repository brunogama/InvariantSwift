import Foundation
import InvariantSwiftCore

// MARK: - GeneratorInterceptor Protocol

/// Protocol for intercepting generator and shrinking operations.
///
/// Implement this protocol to add cross-cutting concerns like logging,
/// validation, or metrics collection to generators. Interceptors provide
/// hooks into the generation lifecycle without modifying generator code.
///
/// The interceptor pattern enables:
/// - **Logging**: Record all generated values for debugging
/// - **Validation**: Assert runtime constraints on generated values
/// - **Metrics**: Track generation counts, shrink steps, test outcomes
/// - **Profiling**: Measure generator performance
///
/// Interceptors are attached via `Gen.withInterceptor()` and can be chained
/// for composable observability.
///
/// - Example:
///   ```swift
///   let gen = Gen<Int>.int
///     .withInterceptor(LoggingInterceptor())
///     .withInterceptor(MetricsInterceptor())
///   // Now generates with logging and metrics tracking
///   ```
///
/// - See Also: ``Gen``, ``LoggingInterceptor``, ``MetricsInterceptor``
public protocol GeneratorInterceptor: Sendable {
  /// Called when a value is generated.
  ///
  /// This hook is invoked immediately after a generator produces a value,
  /// before shrinking occurs. Use it to log, validate, or record the value.
  ///
  /// - Parameters:
  ///   - value: The generated value
  ///   - size: The size parameter used for generation
  ///
  /// - Returns: The value (possibly modified for validation interceptors)
  ///
  /// - Note: For most interceptors, return the value unchanged. Only validation
  ///   interceptors should modify the value.
  func onGenerate<T: Sendable>(_ value: T, size: Size) -> T

  /// Called when a value is shrunk.
  ///
  /// This hook is invoked each time the shrinker produces a candidate
  /// shrunk value during counterexample minimization.
  ///
  /// - Parameters:
  ///   - original: The original value being shrunk
  ///   - shrunk: The shrunk candidate
  ///   - step: The shrink step number (0-indexed)
  ///
  /// - Returns: The shrunk value (typically unchanged)
  func onShrink<T: Sendable>(_ original: T, shrunk: T, step: Int) -> T

  /// Called when a property is evaluated.
  ///
  /// This hook is invoked after testing whether a generated value
  /// satisfies a property, providing visibility into pass/fail outcomes.
  ///
  /// - Parameters:
  ///   - value: The input value tested
  ///   - passed: Whether the property passed for this value
  func onPropertyEvaluated<T: Sendable>(_ value: T, passed: Bool)
}

// MARK: - Default Implementations

extension GeneratorInterceptor {
  /// Default no-op implementation for `onGenerate`.
  public func onGenerate<T: Sendable>(_ value: T, size: Size) -> T {
    value
  }

  /// Default no-op implementation for `onShrink`.
  public func onShrink<T: Sendable>(_ original: T, shrunk: T, step: Int) -> T {
    shrunk
  }

  /// Default no-op implementation for `onPropertyEvaluated`.
  public func onPropertyEvaluated<T: Sendable>(_ value: T, passed: Bool) {}
}

// MARK: - LoggingInterceptor

/// Interceptor that logs all generated and shrunk values.
///
/// `LoggingInterceptor` provides visibility into generator behavior by
/// logging each generated value, shrink step, and property evaluation
/// outcome. This is invaluable for debugging failing property tests.
///
/// Output can be customized via the `output` closure, allowing integration
/// with logging frameworks or test output systems.
///
/// - Example:
///   ```swift
///   var logs: [String] = []
///   let logger = LoggingInterceptor(
///     output: { logs.append($0) }
///   )
///
///   let gen = Gen<Int>.int.withInterceptor(logger)
///   let value = gen.sample(size: Size(value: 50), seed: Seed(value: 42))
///   // logs contains generation output
///   ```
///
/// - See Also: ``GeneratorInterceptor``, ``MetricsInterceptor``
public final class LoggingInterceptor: GeneratorInterceptor, @unchecked Sendable {
  private let output: @Sendable (String) -> Void
  private let includeSize: Bool
  private let includeShrinkSteps: Bool

  /// Initialize a logging interceptor.
  ///
  /// - Parameters:
  ///   - output: Function to receive log messages (defaults to system logging)
  ///   - includeSize: Whether to include size parameter in generate logs (default: true)
  ///   - includeShrinkSteps: Whether to log individual shrink steps (default: true)
  public init(
    // swiftlint:disable:next no_print
    output: @escaping @Sendable (String) -> Void = { print($0) },
    includeSize: Bool = true,
    includeShrinkSteps: Bool = true
  ) {
    self.output = output
    self.includeSize = includeSize
    self.includeShrinkSteps = includeShrinkSteps
  }

  public func onGenerate<T: Sendable>(_ value: T, size: Size) -> T {
    let msg =
      includeSize
      ? "Generated: \(value) (size: \(size.value))"
      : "Generated: \(value)"
    output(msg)
    return value
  }

  public func onShrink<T: Sendable>(_ original: T, shrunk: T, step: Int) -> T {
    if includeShrinkSteps {
      output("Shrink[\(step)]: \(original) -> \(shrunk)")
    }
    return shrunk
  }

  public func onPropertyEvaluated<T: Sendable>(_ value: T, passed: Bool) {
    output("Evaluated: \(passed ? "PASS" : "FAIL") for \(value)")
  }
}

// MARK: - MetricsInterceptor

/// Interceptor that collects metrics about generation and testing.
///
/// `MetricsInterceptor` tracks statistics about generator behavior:
/// - **Generation count**: Total values generated
/// - **Shrink steps**: Total shrink operations performed
/// - **Pass/fail counts**: Property test outcomes
/// - **Average size**: Mean complexity of generated values
///
/// All counters are thread-safe using `NSLock` for compatibility
/// with iOS 17+/macOS 14+ platform requirements.
///
/// - Example:
///   ```swift
///   let (gen, metrics) = Gen<Int>.int.withMetrics()
///
///   // Generate some values
///   for _ in 0..<100 {
///     _ = gen.sample(size: Size.medium, seed: Seed.random())
///   }
///
///   let stats = metrics.metrics
///   // Example output for verification only
///   _ = "Generated: \(stats.generationCount) values"
///   _ = "Average size: \(stats.averageSize)"
///   ```
///
/// - See Also: ``GeneratorInterceptor``, ``LoggingInterceptor``
public final class MetricsInterceptor: GeneratorInterceptor, @unchecked Sendable {
  /// Metrics snapshot capturing generation statistics.
  public struct Metrics: Sendable {
    /// Total number of values generated
    public var generationCount: Int = 0
    /// Total number of shrink operations performed
    public var shrinkSteps: Int = 0
    /// Number of property tests that passed
    public var passCount: Int = 0
    /// Number of property tests that failed
    public var failCount: Int = 0
    /// Sum of all size parameters used
    public var totalSize: Int = 0

    /// Average size parameter across all generations.
    ///
    /// Returns 0 if no values have been generated yet.
    public var averageSize: Double {
      generationCount > 0 ? Double(totalSize) / Double(generationCount) : 0
    }
  }

  private let _lock: NSLock
  private var _metricsStorage: Metrics

  /// Current metrics snapshot.
  ///
  /// Thread-safe read of the current metrics state.
  public var metrics: Metrics {
    _lock.lock()
    defer { _lock.unlock() }
    return _metricsStorage
  }

  /// Initialize a metrics interceptor with zero counters.
  public init() {
    _lock = NSLock()
    _metricsStorage = Metrics()
  }

  public func onGenerate<T: Sendable>(_ value: T, size: Size) -> T {
    _lock.lock()
    _metricsStorage.generationCount += 1
    _metricsStorage.totalSize += size.value
    _lock.unlock()
    return value
  }

  public func onShrink<T: Sendable>(_ original: T, shrunk: T, step: Int) -> T {
    _lock.lock()
    _metricsStorage.shrinkSteps += 1
    _lock.unlock()
    return shrunk
  }

  public func onPropertyEvaluated<T: Sendable>(_ value: T, passed: Bool) {
    _lock.lock()
    if passed {
      _metricsStorage.passCount += 1
    } else {
      _metricsStorage.failCount += 1
    }
    _lock.unlock()
  }

  /// Reset all metrics to zero.
  ///
  /// Thread-safe reset of all counters.
  public func reset() {
    _lock.lock()
    _metricsStorage = Metrics()
    _lock.unlock()
  }
}

// MARK: - ValidationInterceptor

/// Interceptor that validates generated values against constraints.
///
/// `ValidationInterceptor` asserts runtime constraints on generated values,
/// enabling detection of invalid generator output during testing. This is
/// useful for ensuring generators respect preconditions and invariants.
///
/// When a value fails validation, the `onInvalid` callback is invoked,
/// allowing custom handling (logging, throwing, etc).
///
/// - Example:
///   ```swift
///   let validator = ValidationInterceptor<Int>(
///     validate: { $0 >= 0 },
///     onInvalid: { value in
///       // Custom handling for invalid values
///       _ = "Invalid negative value: \(value)"
///     }
///   )
///
///   let gen = Gen<Int>.int.withInterceptor(validator)
///   // Any negative values will trigger onInvalid
///   ```
///
/// - See Also: ``GeneratorInterceptor``, ``LoggingInterceptor``
public final class ValidationInterceptor<T: Sendable>: GeneratorInterceptor, @unchecked Sendable {
  private let validator: @Sendable (T) -> Bool
  private let onInvalid: @Sendable (T) -> Void

  /// Initialize a validation interceptor.
  ///
  /// - Parameters:
  ///   - validate: Predicate that returns true for valid values
  ///   - onInvalid: Callback invoked when a value fails validation (default: no-op)
  public init(
    validate: @escaping @Sendable (T) -> Bool,
    onInvalid: @escaping @Sendable (T) -> Void = { _ in }
  ) {
    self.validator = validate
    self.onInvalid = onInvalid
  }

  public func onGenerate<U: Sendable>(_ value: U, size: Size) -> U {
    if let typedValue = value as? T {
      if !validator(typedValue) {
        onInvalid(typedValue)
      }
    }
    return value
  }

  public func onShrink<U: Sendable>(_ original: U, shrunk: U, step: Int) -> U {
    if let typedValue = shrunk as? T {
      if !validator(typedValue) {
        onInvalid(typedValue)
      }
    }
    return shrunk
  }
}
