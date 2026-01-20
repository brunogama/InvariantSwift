import Foundation
import InvariantSwift
import InvariantSwiftCore
import InvariantSwiftExperimental
import Testing

// MARK: - Test Helpers

final class ThreadSafeArray<Element>: @unchecked Sendable {
  private var storage: [Element] = []
  private let lock = NSLock()

  func append(_ element: Element) {
    lock.lock()
    defer { lock.unlock() }
    storage.append(element)
  }

  var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return storage.count
  }

  subscript(index: Int) -> Element {
    lock.lock()
    defer { lock.unlock() }
    return storage[index]
  }

  var values: [Element] {
    lock.lock()
    defer { lock.unlock() }
    return storage
  }
}

@Suite("Generator Middleware Tests")
struct GeneratorMiddlewareTests {

  // MARK: - LoggingInterceptor Tests

  @Test("LoggingInterceptor logs generated values")
  func loggingInterceptorLogsGeneration() {
    let logs = ThreadSafeArray<String>()
    let logger = LoggingInterceptor(
      output: { logs.append($0) },
      includeSize: true,
      includeShrinkSteps: false
    )

    let value = logger.onGenerate(42, size: Size(value: 50))

    #expect(value == 42)
    #expect(logs.count == 1)
    #expect(logs[0].contains("Generated: 42"))
    #expect(logs[0].contains("size: 50"))
  }

  @Test("LoggingInterceptor logs shrink steps when enabled")
  func loggingInterceptorLogsShrinking() {
    let logs = ThreadSafeArray<String>()
    let logger = LoggingInterceptor(
      output: { logs.append($0) },
      includeSize: false,
      includeShrinkSteps: true
    )

    let shrunk = logger.onShrink(100, shrunk: 50, step: 0)

    #expect(shrunk == 50)
    #expect(logs.count == 1)
    #expect(logs[0].contains("Shrink[0]: 100 -> 50"))
  }

  @Test("LoggingInterceptor logs property evaluation")
  func loggingInterceptorLogsPropertyEvaluation() {
    let logs = ThreadSafeArray<String>()
    let logger = LoggingInterceptor(output: { logs.append($0) })

    logger.onPropertyEvaluated(42, passed: true)
    logger.onPropertyEvaluated(0, passed: false)

    #expect(logs.count == 2)
    #expect(logs[0].contains("PASS"))
    #expect(logs[0].contains("42"))
    #expect(logs[1].contains("FAIL"))
    #expect(logs[1].contains("0"))
  }

  // MARK: - MetricsInterceptor Tests

  @Test("MetricsInterceptor tracks generation count")
  func metricsInterceptorTracksGenerationCount() {
    let metrics = MetricsInterceptor()

    for i in 0..<10 {
      _ = metrics.onGenerate(i, size: Size(value: 50))
    }

    let stats = metrics.metrics
    #expect(stats.generationCount == 10)
  }

  @Test("MetricsInterceptor tracks shrink steps")
  func metricsInterceptorTracksShrinkSteps() {
    let metrics = MetricsInterceptor()

    for i in 0..<5 {
      _ = metrics.onShrink(100, shrunk: 50 - i, step: i)
    }

    let stats = metrics.metrics
    #expect(stats.shrinkSteps == 5)
  }

  @Test("MetricsInterceptor tracks pass/fail counts")
  func metricsInterceptorTracksPassFail() {
    let metrics = MetricsInterceptor()

    metrics.onPropertyEvaluated(1, passed: true)
    metrics.onPropertyEvaluated(2, passed: true)
    metrics.onPropertyEvaluated(3, passed: false)

    let stats = metrics.metrics
    #expect(stats.passCount == 2)
    #expect(stats.failCount == 1)
  }

  @Test("MetricsInterceptor calculates average size")
  func metricsInterceptorCalculatesAverageSize() {
    let metrics = MetricsInterceptor()

    _ = metrics.onGenerate(1, size: Size(value: 10))
    _ = metrics.onGenerate(2, size: Size(value: 20))
    _ = metrics.onGenerate(3, size: Size(value: 30))

    let stats = metrics.metrics
    #expect(stats.averageSize == 20.0)
  }

  @Test("MetricsInterceptor reset clears all counters")
  func metricsInterceptorResetClearsCounters() {
    let metrics = MetricsInterceptor()

    _ = metrics.onGenerate(1, size: Size(value: 10))
    metrics.onPropertyEvaluated(1, passed: true)

    metrics.reset()

    let stats = metrics.metrics
    #expect(stats.generationCount == 0)
    #expect(stats.passCount == 0)
    #expect(stats.averageSize == 0.0)
  }

  // MARK: - ValidationInterceptor Tests

  @Test("ValidationInterceptor calls onInvalid for invalid values")
  func validationInterceptorCallsOnInvalid() {
    let invalidValues = ThreadSafeArray<Int>()
    let validator = ValidationInterceptor<Int>(
      validate: { $0 >= 0 },
      onInvalid: { invalidValues.append($0) }
    )

    _ = validator.onGenerate(42, size: Size(value: 50))
    _ = validator.onGenerate(-10, size: Size(value: 50))

    #expect(invalidValues.count == 1)
    #expect(invalidValues[0] == -10)
  }

  @Test("ValidationInterceptor validates shrunk values")
  func validationInterceptorValidatesShrunkValues() {
    let invalidValues = ThreadSafeArray<Int>()
    let validator = ValidationInterceptor<Int>(
      validate: { $0 >= 0 },
      onInvalid: { invalidValues.append($0) }
    )

    _ = validator.onShrink(100, shrunk: 50, step: 0)
    _ = validator.onShrink(10, shrunk: -5, step: 1)

    #expect(invalidValues.count == 1)
    #expect(invalidValues[0] == -5)
  }

  // MARK: - Gen.withInterceptor Tests

  @Test("Gen.withInterceptor attaches single interceptor")
  func genWithInterceptorAttachesSingle() {
    let logs = ThreadSafeArray<String>()
    let logger = LoggingInterceptor(output: { logs.append($0) })

    let gen = Gen<Int>.int.withInterceptor(logger)
    let value = gen.sample(size: Size(value: 50), seed: Seed(value: 42))

    #expect(value != 0)  // Sanity check generation works
    #expect(logs.count == 1)
    #expect(logs[0].contains("Generated:"))
  }

  @Test("Gen.withInterceptors chains multiple interceptors")
  func genWithInterceptorsChains() {
    let logs = ThreadSafeArray<String>()
    let logger = LoggingInterceptor(output: { logs.append($0) })
    let metrics = MetricsInterceptor()

    let gen = Gen<Int>.int.withInterceptors([logger, metrics])
    _ = gen.sample(size: Size(value: 50), seed: Seed(value: 42))

    #expect(logs.count == 1)
    #expect(metrics.metrics.generationCount == 1)
  }

  @Test("Gen.logged convenience method works")
  func genLoggedConvenienceWorks() {
    let logs = ThreadSafeArray<String>()
    let gen = Gen<Int>.int.logged { logs.append($0) }

    _ = gen.sample(size: Size(value: 50), seed: Seed(value: 42))

    #expect(logs.count == 1)
    #expect(logs[0].contains("Generated:"))
  }

  @Test("Gen.withMetrics returns working metrics handle")
  func genWithMetricsReturnsWorkingHandle() {
    let (gen, metrics) = Gen<Int>.int.withMetrics()

    for _ in 0..<10 {
      _ = gen.sample(size: Size(value: 50), seed: Seed.random)
    }

    let stats = metrics.metrics
    #expect(stats.generationCount == 10)
  }

  // MARK: - Integration with Shrinking

  @Test("Interceptor tracks shrink operations")
  func interceptorTracksShrinkOperations() {
    let metrics = MetricsInterceptor()
    let gen = Gen<Int> { rng, _ in Int.random(in: 0..<100, using: &rng) }
      .withShrink { n in
        guard n > 0 else { return [] }
        return [0, n / 2, n - 1]
      }
      .withInterceptor(metrics)

    // Generate and manually shrink
    let value = gen.sample(size: Size(value: 50), seed: Seed(value: 42))
    let shrinks = gen.shrink.shrink(value)

    #expect(shrinks.count == 3)
    #expect(metrics.metrics.shrinkSteps == 3)
  }

  // MARK: - Thread Safety Tests

  @Test("MetricsInterceptor is thread-safe")
  func metricsInterceptorIsThreadSafe() async {
    let metrics = MetricsInterceptor()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<100 {
        group.addTask {
          _ = metrics.onGenerate(42, size: Size(value: 50))
        }
      }
    }

    let stats = metrics.metrics
    #expect(stats.generationCount == 100)
  }
}
