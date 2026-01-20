import Foundation

/// Error thrown when a property test exceeds its configured timeout.
public struct PropertyTimeoutError: Error, Sendable {
  public let elapsed: TimeInterval
  public let limit: TimeInterval

  public init(elapsed: TimeInterval, limit: TimeInterval) {
    self.elapsed = elapsed
    self.limit = limit
  }
}

extension PropertyTimeoutError: CustomStringConvertible {
  public var description: String {
    let elapsedStr = String(format: "%.1f", elapsed)
    let limitStr = String(format: "%.1f", limit)
    return "Property test timed out after \(elapsedStr)s (limit: \(limitStr)s)"
  }
}

extension PropertyTimeoutError: LocalizedError {
  public var errorDescription: String? {
    description
  }
}

/// Specifies a timeout duration for property test execution.
///
/// Use this to control how long a property test can run before timing out.
/// The `.none` case disables timeouts, useful for debugging.
public enum TimeoutDuration: Sendable, Equatable {
  /// Timeout after the specified number of seconds.
  case seconds(TimeInterval)

  /// Timeout after the specified number of milliseconds.
  case milliseconds(Int)

  /// No timeout (useful for debugging).
  case none

  /// Convert the duration to nanoseconds for use with `Task.sleep`.
  ///
  /// Returns `nil` if timeout is disabled (`.none`).
  public var nanoseconds: UInt64? {
    switch self {
    case .seconds(let s):
      return UInt64(s * 1_000_000_000)

    case .milliseconds(let ms):
      return UInt64(ms) * 1_000_000

    case .none:
      return nil
    }
  }

  /// The timeout duration in seconds, or `nil` if disabled.
  public var timeInterval: TimeInterval? {
    switch self {
    case .seconds(let s):
      return s

    case .milliseconds(let ms):
      return TimeInterval(ms) / 1000.0

    case .none:
      return nil
    }
  }
}

/// Executes an async operation with a timeout.
///
/// This function uses Swift Concurrency task racing to enforce a timeout.
/// If the operation completes before the timeout, its result is returned.
/// If the timeout expires first, `PropertyTimeoutError` is thrown.
///
/// Thread Safety: This function is thread-safe and uses structured concurrency
/// to ensure proper cleanup. The remaining task is cancelled after the first
/// task completes.
///
/// - Parameters:
///   - duration: The timeout duration. Use `.none` to disable timeout.
///   - operation: The async operation to execute with a timeout.
/// - Returns: The result of the operation if it completes within the timeout.
/// - Throws: `PropertyTimeoutError` if the timeout expires, or any error thrown by `operation`.
public func withPropertyTimeout<T: Sendable>(
  _ duration: TimeoutDuration,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  guard let nanos = duration.nanoseconds else {
    // .none - no timeout, run directly
    return try await operation()
  }

  let startTime = Date()

  return try await withThrowingTaskGroup(of: T.self) { group in
    // Task 1: Run the actual operation
    group.addTask {
      try await operation()
    }

    // Task 2: Timeout timer
    group.addTask {
      try await Task.sleep(nanoseconds: nanos)
      let elapsed = Date().timeIntervalSince(startTime)
      let limit = duration.timeInterval ?? 0
      throw PropertyTimeoutError(elapsed: elapsed, limit: limit)
    }

    // Wait for the first task to complete
    guard let result = try await group.next() else {
      throw CancellationError()
    }

    // Cancel the remaining task
    group.cancelAll()

    return result
  }
}

/// Executes an async operation with a timeout specified in seconds.
///
/// This is a convenience overload of `withPropertyTimeout(_:operation:)` that
/// accepts a `TimeInterval` directly.
///
/// - Parameters:
///   - seconds: Maximum execution time in seconds.
///   - operation: The async operation to execute with a timeout.
/// - Returns: The result of the operation if it completes within the timeout.
/// - Throws: `PropertyTimeoutError` if the timeout expires, or any error thrown by `operation`.
public func withPropertyTimeout<T: Sendable>(
  seconds: TimeInterval,
  operation: @escaping @Sendable () async throws -> T
) async throws -> T {
  try await withPropertyTimeout(.seconds(seconds), operation: operation)
}
