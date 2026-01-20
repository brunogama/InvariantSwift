import Foundation
import InvariantSwiftCore

// MARK: - Generator Middleware Extensions

extension Gen {
  /// Attaches an interceptor to this generator.
  ///
  /// The interceptor's hooks are called during generation and shrinking,
  /// enabling cross-cutting concerns like logging, validation, and metrics
  /// without modifying generator code.
  ///
  /// Multiple interceptors can be chained by calling this method repeatedly.
  /// Interceptors are invoked in the order they are attached.
  ///
  /// - Parameter interceptor: The interceptor to attach
  /// - Returns: A new generator with the interceptor attached
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int>.int
  ///     .withInterceptor(LoggingInterceptor())
  ///     .withInterceptor(MetricsInterceptor())
  ///   // Logs and tracks metrics for all generated values
  ///   ```
  ///
  /// - See Also: ``GeneratorInterceptor``, ``withInterceptors(_:)``, ``logged(output:)``
  public func withInterceptor(_ interceptor: some GeneratorInterceptor) -> Gen<T> {
    Gen<T>(
      generate: { rng, size in
        let value = self.generate(&rng, size)
        return interceptor.onGenerate(value, size: size)
      },
      shrink: Shrink<T> { value in
        self.shrink.shrink(value).enumerated().map { idx, shrunk in
          interceptor.onShrink(value, shrunk: shrunk, step: idx)
        }
      }
    )
  }

  /// Attaches multiple interceptors in order.
  ///
  /// Equivalent to calling `withInterceptor(_:)` for each interceptor
  /// in sequence. Interceptors are invoked in the order provided.
  ///
  /// - Parameter interceptors: Array of interceptors to attach
  /// - Returns: A new generator with all interceptors attached
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int>.int.withInterceptors([
  ///     LoggingInterceptor(),
  ///     MetricsInterceptor(),
  ///     ValidationInterceptor(validate: { $0 >= 0 })
  ///   ])
  ///   ```
  ///
  /// - See Also: ``withInterceptor(_:)``
  public func withInterceptors(_ interceptors: [any GeneratorInterceptor]) -> Gen<T> {
    interceptors.reduce(self) { gen, interceptor in
      gen.withInterceptor(interceptor)
    }
  }

  /// Attaches a logging interceptor for debugging.
  ///
  /// Convenience method that creates and attaches a `LoggingInterceptor`
  /// with the specified output function.
  ///
  /// - Parameter output: Custom output function (defaults to system logging)
  /// - Returns: A new generator with logging attached
  ///
  /// - Example:
  ///   ```swift
  ///   var logs: [String] = []
  ///   let gen = Gen<Int>.int.logged { logs.append($0) }
  ///   _ = gen.sample(size: Size.medium, seed: Seed(value: 42))
  ///   // logs contains generation output
  ///   ```
  ///
  /// - See Also: ``LoggingInterceptor``, ``withInterceptor(_:)``
  public func logged(
    // swiftlint:disable:next no_print
    output: @escaping @Sendable (String) -> Void = { print($0) }
  ) -> Gen<T> {
    withInterceptor(LoggingInterceptor(output: output))
  }

  /// Attaches a metrics interceptor and returns both the generator and metrics handle.
  ///
  /// Creates a `MetricsInterceptor`, attaches it to the generator, and returns
  /// both the instrumented generator and a reference to the metrics for inspection.
  ///
  /// - Returns: Tuple of (instrumented generator, metrics interceptor)
  ///
  /// - Example:
  ///   ```swift
  ///   let (gen, metrics) = Gen<Int>.int.withMetrics()
  ///
  ///   // Use generator
  ///   for _ in 0..<100 {
  ///     _ = gen.sample(size: Size.medium, seed: Seed.random())
  ///   }
  ///
  ///   // Inspect metrics
  ///   let stats = metrics.metrics
  ///   // Example output for verification only
  ///   _ = "Generated \(stats.generationCount) values"
  ///   _ = "Average size: \(stats.averageSize)"
  ///   ```
  ///
  /// - See Also: ``MetricsInterceptor``, ``withInterceptor(_:)``
  public func withMetrics() -> (Gen<T>, MetricsInterceptor) {
    let metrics = MetricsInterceptor()
    return (withInterceptor(metrics), metrics)
  }
}
