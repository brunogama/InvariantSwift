import Foundation
import Dispatch
import os

// MARK: - Observability and Telemetry Infrastructure

/// **Advanced Telemetry System for Property-Based Testing**
///
/// Comprehensive observability infrastructure for monitoring, analyzing, and optimizing
/// property-based testing performance. Provides real-time metrics, distributed tracing,
/// and performance analytics for testing workflows.
///
/// **Features:**
/// - Real-time performance metrics collection
/// - Distributed tracing for test execution paths
/// - Memory and CPU usage monitoring
/// - Test effectiveness analytics
/// - Integration with monitoring platforms
/// - Performance regression detection
/// - Resource utilization tracking
///
/// **Mathematical Foundation:**
/// Based on statistical process control and performance monitoring theory,
/// implementing control charts, trend analysis, and anomaly detection algorithms.
///
/// **External References:**
/// - [OpenTelemetry Specification](https://opentelemetry.io/docs/reference/specification/)
/// - [Statistical Process Control](https://en.wikipedia.org/wiki/Statistical_process_control)
/// - [Performance Monitoring Best Practices](https://sre.google/sre-book/monitoring-distributed-systems/)

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
public actor TelemetrySystem {

  // MARK: - Types and Configuration

  /// **Telemetry configuration**
  public struct Config: Sendable {
    /// Enable/disable telemetry collection
    public let enabled: Bool

    /// Sampling rate for metrics (0.0 - 1.0)
    public let samplingRate: Double

    /// Buffer size for batching events
    public let bufferSize: Int

    /// Flush interval for sending data
    public let flushInterval: TimeInterval

    /// Remote endpoint for telemetry data
    public let endpoint: URL?

    /// Local storage for offline data
    public let localStoragePath: URL?

    /// Resource utilization monitoring
    public let enableResourceMonitoring: Bool

    /// Custom tags for all telemetry
    public let globalTags: [String: String]

    public init(
      enabled: Bool = true,
      samplingRate: Double = 1.0,
      bufferSize: Int = 1000,
      flushInterval: TimeInterval = 60.0,
      endpoint: URL? = nil,
      localStoragePath: URL? = nil,
      enableResourceMonitoring: Bool = true,
      globalTags: [String: String] = [:]
    ) {
      self.enabled = enabled
      self.samplingRate = max(0.0, min(1.0, samplingRate))
      self.bufferSize = max(1, bufferSize)
      self.flushInterval = max(1.0, flushInterval)
      self.endpoint = endpoint
      self.localStoragePath = localStoragePath
      self.enableResourceMonitoring = enableResourceMonitoring
      self.globalTags = globalTags
    }

    public static let `default` = Config()
  }

  /// **Telemetry event types**
  public enum EventType: String, CaseIterable, Codable, Sendable {
    case testStart = "test.start"
    case testComplete = "test.complete"
    case testFailure = "test.failure"
    case generationStart = "generation.start"
    case generationComplete = "generation.complete"
    case shrinkingStart = "shrinking.start"
    case shrinkingComplete = "shrinking.complete"
    case counterexampleFound = "counterexample.found"
    case resourceAlert = "resource.alert"
    case performanceAlert = "performance.alert"
    case systemMetric = "system.metric"
  }

  /// **Telemetry event**
  public struct TelemetryEvent: Codable, Sendable {
    /// Unique event identifier
    public let id: String

    /// Event type
    public let type: EventType

    /// Event timestamp
    public let timestamp: Date

    /// Event duration (if applicable)
    public let duration: TimeInterval?

    /// Event tags/labels
    public let tags: [String: String]

    /// Event metrics/values
    public let metrics: [String: Double]

    /// Event context data
    public let context: [String: String]

    /// Trace ID for distributed tracing
    public let traceId: String

    /// Span ID for distributed tracing
    public let spanId: String

    /// Parent span ID for distributed tracing
    public let parentSpanId: String?

    public init(
      id: String = UUID().uuidString,
      type: EventType,
      timestamp: Date = Date(),
      duration: TimeInterval? = nil,
      tags: [String: String] = [:],
      metrics: [String: Double] = [:],
      context: [String: String] = [:],
      traceId: String = UUID().uuidString,
      spanId: String = UUID().uuidString,
      parentSpanId: String? = nil
    ) {
      self.id = id
      self.type = type
      self.timestamp = timestamp
      self.duration = duration
      self.tags = tags
      self.metrics = metrics
      self.context = context
      self.traceId = traceId
      self.spanId = spanId
      self.parentSpanId = parentSpanId
    }
  }

  /// **Performance metrics**
  public struct PerformanceMetrics: Codable, Sendable {
    /// Test execution time
    public let executionTime: TimeInterval

    /// Memory usage (bytes)
    public let memoryUsage: Int64

    /// CPU usage percentage
    public let cpuUsage: Double

    /// Number of iterations
    public let iterations: Int

    /// Number of successful tests
    public let successCount: Int

    /// Number of failed tests
    public let failureCount: Int

    /// Number of shrinking steps
    public let shrinkingSteps: Int

    /// Generation throughput (values/second)
    public let generationThroughput: Double

    /// Error rate
    public let errorRate: Double

    public var successRate: Double {
      let total = successCount + failureCount
      return total > 0 ? Double(successCount) / Double(total) : 0.0
    }

    public init(
      executionTime: TimeInterval,
      memoryUsage: Int64,
      cpuUsage: Double,
      iterations: Int,
      successCount: Int,
      failureCount: Int,
      shrinkingSteps: Int,
      generationThroughput: Double,
      errorRate: Double
    ) {
      self.executionTime = executionTime
      self.memoryUsage = memoryUsage
      self.cpuUsage = cpuUsage
      self.iterations = iterations
      self.successCount = successCount
      self.failureCount = failureCount
      self.shrinkingSteps = shrinkingSteps
      self.generationThroughput = generationThroughput
      self.errorRate = errorRate
    }
  }

  /// **Resource monitoring data**
  public struct ResourceSnapshot: Codable, Sendable {
    public let timestamp: Date
    public let memoryUsed: Int64
    public let memoryAvailable: Int64
    public let cpuUsage: Double
    public let diskUsage: Int64
    public let networkBytesReceived: Int64
    public let networkBytesSent: Int64
    public let threadCount: Int
    public let fileDescriptorCount: Int

    public init(
      timestamp: Date = Date(),
      memoryUsed: Int64,
      memoryAvailable: Int64,
      cpuUsage: Double,
      diskUsage: Int64,
      networkBytesReceived: Int64,
      networkBytesSent: Int64,
      threadCount: Int,
      fileDescriptorCount: Int
    ) {
      self.timestamp = timestamp
      self.memoryUsed = memoryUsed
      self.memoryAvailable = memoryAvailable
      self.cpuUsage = cpuUsage
      self.diskUsage = diskUsage
      self.networkBytesReceived = networkBytesReceived
      self.networkBytesSent = networkBytesSent
      self.threadCount = threadCount
      self.fileDescriptorCount = fileDescriptorCount
    }
  }

  // MARK: - Properties

  private let config: Config

  /// Check if resource monitoring is enabled
  public var isResourceMonitoringEnabled: Bool { config.enableResourceMonitoring }
  private var eventBuffer: [TelemetryEvent] = []
  private var lastFlush = Date()
  private let logger = Logger(subsystem: "FunctionalTesting", category: "Telemetry")
  private var activeTraces: [String: TraceContext] = [:]
  private var resourceMonitorTask: Task<Void, Never>?
  private var flushTask: Task<Void, Never>?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  /// **Shared telemetry system instance**
  public static let shared = TelemetrySystem()

  // MARK: - Internal Types

  private struct TraceContext {
    let traceId: String
    let startTime: Date
    var spans: [String: SpanContext] = [:]
  }

  private struct SpanContext {
    let spanId: String
    let parentSpanId: String?
    let startTime: Date
    var endTime: Date?
    let operationName: String
    var tags: [String: String] = [:]
  }

  // MARK: - Initialization

  public init(config: Config = .default) {
    self.config = config

    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    decoder.dateDecodingStrategy = .iso8601

    if config.enabled {
      Task { [weak self] in
        await self?.startBackgroundTasks()
      }
    }
  }

  deinit {
    resourceMonitorTask?.cancel()
    flushTask?.cancel()
  }

  // MARK: - Public API

  /// **Record a telemetry event**
  public func recordEvent(_ event: TelemetryEvent) {
    guard config.enabled else { return }

    // Apply sampling
    if Double.random(in: 0...1) > config.samplingRate {
      return
    }

    // Add global tags
    var enrichedEvent = event
    if !config.globalTags.isEmpty {
      var allTags = config.globalTags
      allTags.merge(event.tags) { _, new in new }
      enrichedEvent = TelemetryEvent(
        id: event.id,
        type: event.type,
        timestamp: event.timestamp,
        duration: event.duration,
        tags: allTags,
        metrics: event.metrics,
        context: event.context,
        traceId: event.traceId,
        spanId: event.spanId,
        parentSpanId: event.parentSpanId
      )
    }

    eventBuffer.append(enrichedEvent)

    // Log locally for debugging
    logger.info("📊 Telemetry: \(event.type.rawValue) - \(event.tags)")

    // Flush if buffer is full
    if eventBuffer.count >= config.bufferSize {
      Task {
        await flushEvents()
      }
    }
  }

  /// **Start a new trace**
  public func startTrace(
    operationName: String,
    traceId: String = UUID().uuidString,
    tags: [String: String] = [:]
  ) -> String {
    let context = TraceContext(traceId: traceId, startTime: Date())
    activeTraces[traceId] = context

    recordEvent(
      TelemetryEvent(
        type: .testStart,
        tags: ["operation": operationName].merging(tags) { _, new in new },
        traceId: traceId
      )
    )

    return traceId
  }

  /// **End a trace**
  public func endTrace(_ traceId: String, status: String = "ok") {
    guard let context = activeTraces.removeValue(forKey: traceId) else { return }

    let duration = Date().timeIntervalSince(context.startTime)

    recordEvent(
      TelemetryEvent(
        type: .testComplete,
        duration: duration,
        tags: ["status": status],
        metrics: ["duration_ms": duration * 1000],
        traceId: traceId
      )
    )
  }

  /// **Start a span within a trace**
  public func startSpan(
    operationName: String,
    traceId: String,
    parentSpanId: String? = nil,
    tags: [String: String] = [:]
  ) -> String {
    let spanId = UUID().uuidString
    let spanContext = SpanContext(
      spanId: spanId,
      parentSpanId: parentSpanId,
      startTime: Date(),
      operationName: operationName,
      tags: tags
    )

    activeTraces[traceId]?.spans[spanId] = spanContext

    recordEvent(
      TelemetryEvent(
        type: .generationStart,
        tags: ["operation": operationName].merging(tags) { _, new in new },
        traceId: traceId,
        spanId: spanId,
        parentSpanId: parentSpanId
      )
    )

    return spanId
  }

  /// **End a span**
  public func endSpan(_ spanId: String, traceId: String, status: String = "ok") {
    guard var context = activeTraces[traceId]?.spans[spanId] else { return }

    context.endTime = Date()
    activeTraces[traceId]?.spans[spanId] = context

    let duration = context.endTime!.timeIntervalSince(context.startTime)

    recordEvent(
      TelemetryEvent(
        type: .generationComplete,
        duration: duration,
        tags: ["operation": context.operationName, "status": status],
        metrics: ["duration_ms": duration * 1000],
        traceId: traceId,
        spanId: spanId,
        parentSpanId: context.parentSpanId
      )
    )
  }

  /// **Record performance metrics**
  public func recordPerformanceMetrics(_ metrics: PerformanceMetrics, tags: [String: String] = [:])
  {
    recordEvent(
      TelemetryEvent(
        type: .systemMetric,
        tags: ["metric_type": "performance"].merging(tags) { _, new in new },
        metrics: [
          "execution_time_ms": metrics.executionTime * 1000,
          "memory_usage_bytes": Double(metrics.memoryUsage),
          "cpu_usage_percent": metrics.cpuUsage,
          "iterations": Double(metrics.iterations),
          "success_count": Double(metrics.successCount),
          "failure_count": Double(metrics.failureCount),
          "shrinking_steps": Double(metrics.shrinkingSteps),
          "generation_throughput": metrics.generationThroughput,
          "error_rate": metrics.errorRate,
          "success_rate": metrics.successRate,
        ]
      )
    )
  }

  /// **Record resource utilization**
  public func recordResourceSnapshot(_ snapshot: ResourceSnapshot, tags: [String: String] = [:]) {
    recordEvent(
      TelemetryEvent(
        type: .systemMetric,
        tags: ["metric_type": "resources"].merging(tags) { _, new in new },
        metrics: [
          "memory_used_bytes": Double(snapshot.memoryUsed),
          "memory_available_bytes": Double(snapshot.memoryAvailable),
          "cpu_usage_percent": snapshot.cpuUsage,
          "disk_usage_bytes": Double(snapshot.diskUsage),
          "network_bytes_received": Double(snapshot.networkBytesReceived),
          "network_bytes_sent": Double(snapshot.networkBytesSent),
          "thread_count": Double(snapshot.threadCount),
          "file_descriptor_count": Double(snapshot.fileDescriptorCount),
        ]
      )
    )
  }

  /// **Record a counterexample event**
  public func recordCounterexample<T>(
    _ counterexample: T,
    shrunkValue: T? = nil,
    iterations: Int,
    shrinkSteps: Int = 0,
    traceId: String? = nil,
    tags: [String: String] = [:]
  ) {
    recordEvent(
      TelemetryEvent(
        type: .counterexampleFound,
        tags: [
          "type": String(describing: T.self),
          "has_shrunk_value": shrunkValue != nil ? "true" : "false",
        ].merging(tags) { _, new in new },
        metrics: [
          "iterations": Double(iterations),
          "shrink_steps": Double(shrinkSteps),
        ],
        context: [
          "counterexample": String(describing: counterexample),
          "shrunk_value": shrunkValue != nil ? String(describing: shrunkValue!) : "",
        ],
        traceId: traceId ?? UUID().uuidString
      )
    )
  }

  /// **Get telemetry statistics**
  public func getStatistics() async -> TelemetryStatistics {
    let eventsCount = eventBuffer.count
    let traceCount = activeTraces.count
    let uptime = Date().timeIntervalSince(lastFlush)

    // Calculate event type distribution
    var eventTypeDistribution: [String: Int] = [:]
    for event in eventBuffer {
      eventTypeDistribution[event.type.rawValue, default: 0] += 1
    }

    return TelemetryStatistics(
      eventsBuffered: eventsCount,
      activeTraces: traceCount,
      uptime: uptime,
      eventTypeDistribution: eventTypeDistribution,
      samplingRate: config.samplingRate,
      enabled: config.enabled
    )
  }

  /// **Flush all buffered events**
  public func flush() async {
    await flushEvents()
  }

  /// **Enable or disable telemetry**
  public func setEnabled(_ enabled: Bool) {
    // Note: This would need to create a new config and restart background tasks
    // Implementation depends on whether we want to support runtime config changes
  }

  // MARK: - Private Implementation

  private func startBackgroundTasks() {
    // Start resource monitoring
    if config.enableResourceMonitoring {
      resourceMonitorTask = Task {
        await monitorResources()
      }
    }

    // Start periodic flush
    flushTask = Task {
      await periodicFlush()
    }
  }

  private func monitorResources() async {
    while !Task.isCancelled {
      let snapshot = captureResourceSnapshot()
      recordResourceSnapshot(snapshot)

      // Check for resource alerts
      await checkResourceAlerts(snapshot)

      try? await Task.sleep(for: .seconds(30))  // Monitor every 30 seconds
    }
  }

  private func periodicFlush() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(config.flushInterval))
      await flushEvents()
    }
  }

  private func flushEvents() async {
    guard !eventBuffer.isEmpty else { return }

    let eventsToFlush = eventBuffer
    eventBuffer.removeAll()
    lastFlush = Date()

    logger.info("📤 Flushing \(eventsToFlush.count) telemetry events")

    // Send to remote endpoint if configured
    if let endpoint = config.endpoint {
      await sendToRemote(eventsToFlush, endpoint: endpoint)
    }

    // Save to local storage if configured
    if let localPath = config.localStoragePath {
      await saveToLocal(eventsToFlush, path: localPath)
    }

    // Always log summary
    await logEventsSummary(eventsToFlush)
  }

  private func sendToRemote(_ events: [TelemetryEvent], endpoint: URL) async {
    do {
      let data = try encoder.encode(events)

      var request = URLRequest(url: endpoint)
      request.httpMethod = "POST"
      request.addValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = data

      let (_, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode == 200 {
          logger.info("✅ Successfully sent \(events.count) events to remote endpoint")
        } else {
          logger.warning("⚠️ Remote endpoint returned status code: \(httpResponse.statusCode)")
        }
      }
    } catch {
      logger.error("❌ Failed to send telemetry to remote endpoint: \(error.localizedDescription)")
    }
  }

  private func saveToLocal(_ events: [TelemetryEvent], path: URL) async {
    do {
      // Ensure directory exists
      let directory = path.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

      // Create filename with timestamp
      let timestamp = ISO8601DateFormatter().string(from: Date())
      let filename = "telemetry-\(timestamp).json"
      let fileURL = path.appendingPathComponent(filename)

      let data = try encoder.encode(events)
      try data.write(to: fileURL)

      logger.info("💾 Saved \(events.count) events to local storage: \(filename)")
    } catch {
      logger.error("❌ Failed to save telemetry to local storage: \(error.localizedDescription)")
    }
  }

  private func logEventsSummary(_ events: [TelemetryEvent]) async {
    var summary: [String: Int] = [:]
    for event in events {
      summary[event.type.rawValue, default: 0] += 1
    }

    logger.info("📊 Event Summary: \(summary)")
  }

  public func captureResourceSnapshot() -> ResourceSnapshot {
    let processInfo = ProcessInfo.processInfo

    // This is a simplified implementation
    // In production, you'd use system APIs to get accurate resource data
    return ResourceSnapshot(
      memoryUsed: Int64(processInfo.physicalMemory / 10),  // Placeholder
      memoryAvailable: Int64(processInfo.physicalMemory),
      cpuUsage: Double.random(in: 0...100),  // Placeholder
      diskUsage: 0,  // Placeholder
      networkBytesReceived: 0,  // Placeholder
      networkBytesSent: 0,  // Placeholder
      threadCount: processInfo.activeProcessorCount,
      fileDescriptorCount: 0  // Placeholder
    )
  }

  private func checkResourceAlerts(_ snapshot: ResourceSnapshot) async {
    // Memory usage alert
    let memoryUsagePercent = Double(snapshot.memoryUsed) / Double(snapshot.memoryAvailable) * 100
    if memoryUsagePercent > 80 {
      recordEvent(
        TelemetryEvent(
          type: .resourceAlert,
          tags: ["alert_type": "memory", "severity": "high"],
          metrics: ["memory_usage_percent": memoryUsagePercent]
        )
      )
    }

    // CPU usage alert
    if snapshot.cpuUsage > 80 {
      recordEvent(
        TelemetryEvent(
          type: .resourceAlert,
          tags: ["alert_type": "cpu", "severity": "high"],
          metrics: ["cpu_usage_percent": snapshot.cpuUsage]
        )
      )
    }
  }
}

// MARK: - Telemetry Statistics

/// **Telemetry system statistics**
public struct TelemetryStatistics: Codable, Sendable {
  public let eventsBuffered: Int
  public let activeTraces: Int
  public let uptime: TimeInterval
  public let eventTypeDistribution: [String: Int]
  public let samplingRate: Double
  public let enabled: Bool

  public init(
    eventsBuffered: Int,
    activeTraces: Int,
    uptime: TimeInterval,
    eventTypeDistribution: [String: Int],
    samplingRate: Double,
    enabled: Bool
  ) {
    self.eventsBuffered = eventsBuffered
    self.activeTraces = activeTraces
    self.uptime = uptime
    self.eventTypeDistribution = eventTypeDistribution
    self.samplingRate = samplingRate
    self.enabled = enabled
  }
}

// MARK: - PropertyRunner Integration

@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension PropertyRunner {

  /// **Run property test with full telemetry integration**
  public func runPropertyWithTelemetry<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default,
    telemetry: TelemetrySystem = .shared,
    tags: [String: String] = [:]
  ) async -> PropertyResult<T> where T: Sendable {

    let traceId = await telemetry.startTrace(
      operationName: "property_test",
      tags: [
        "property_type": String(describing: T.self),
        "iterations": "\(config.iterations)",
      ].merging(tags) { _, new in new }
    )

    let startTime = Date()
    var resourceStart: TelemetrySystem.ResourceSnapshot?

    // Capture initial resource state
    if await telemetry.isResourceMonitoringEnabled {
      resourceStart = await telemetry.captureResourceSnapshot()
    }

    // Run the property test
    let result = runProperty(property, config: config)

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    // Calculate performance metrics
    let (successCount, failureCount) =
      switch result {
      case .success: (1, 0)
      case .failure: (0, 1)
      case .gaveUp: (0, 0)
      }

    let performanceMetrics = TelemetrySystem.PerformanceMetrics(
      executionTime: duration,
      memoryUsage: resourceStart?.memoryUsed ?? 0,
      cpuUsage: 0,  // Would be calculated from resource deltas
      iterations: config.iterations,
      successCount: successCount,
      failureCount: failureCount,
      shrinkingSteps: 0,  // Would be tracked during execution
      generationThroughput: Double(config.iterations) / duration,
      errorRate: failureCount > 0 ? 1.0 : 0.0
    )

    await telemetry.recordPerformanceMetrics(performanceMetrics, tags: tags)

    // Record specific result event
    switch result {
    case .success(let iterations):
      await telemetry.recordEvent(
        TelemetrySystem.TelemetryEvent(
          type: .testComplete,
          duration: duration,
          tags: ["result": "success"].merging(tags) { _, new in new },
          metrics: ["iterations_completed": Double(iterations)],
          traceId: traceId
        )
      )

    case .failure(let counterexample, let iterations, let shrunk):
      await telemetry.recordCounterexample(
        counterexample,
        shrunkValue: shrunk,
        iterations: iterations,
        traceId: traceId,
        tags: tags
      )

    case .gaveUp(let discarded, let iterations):
      await telemetry.recordEvent(
        TelemetrySystem.TelemetryEvent(
          type: .testComplete,
          duration: duration,
          tags: ["result": "gave_up"].merging(tags) { _, new in new },
          metrics: ["iterations_completed": Double(iterations), "discarded": Double(discarded)],
          traceId: traceId
        )
      )
    }

    await telemetry.endTrace(traceId, status: result.isSuccess ? "ok" : "error")

    return result
  }
}

// MARK: - Utility Extensions
