// MARK: - IsolationResult

/// The outcome of executing a property test body through an isolation strategy.
///
/// Each case represents a distinct terminal state: the test passed, failed normally,
/// detected a crash, or exceeded its allowed runtime.
public enum IsolationResult: Sendable {

  /// The test body executed and returned `true`.
  case success

  /// The test body returned `false` or encountered a non-crash error.
  ///
  /// - Parameter reason: A human-readable description of why the test failed.
  case failure(reason: String)

  /// Crash detected during test execution.
  ///
  /// - Parameters:
  ///   - signal: The UNIX signal number that caused the crash.
  ///   - stderr: Raw stderr text captured at crash time.
  ///   - backtrace: Stack frames at the crash point (may be empty).
  ///   - isSymbolicated: Whether frames are human-readable function names.
  case crashed(signal: Int32, stderr: String, backtrace: [String], isSymbolicated: Bool)

  /// Execution exceeded the configured time limit.
  case timeout
}

// MARK: - IsolationStrategy

/// A protocol describing a crash-isolation backend for property test execution.
///
/// Conforming types implement a specific isolation mechanism (e.g. subprocess,
/// thread-based, or in-process passthrough) and report results as `IsolationResult`.
///
/// **Design note:** The `execute(body:)` method is appropriate for in-process
/// strategies (passthrough, thread-based). The subprocess backend (`PosixSpawnIsolation`)
/// also conforms to this protocol, but its primary execution path is the separate
/// `executeViaSubprocess(request:)` method — not declared here — which handles IPC.
/// `IsolatedPropertyRunner` dispatches based on `strategy.capability` to choose
/// the correct path, keeping this protocol simple and broadly applicable.
public protocol IsolationStrategy: Sendable {

  /// The isolation tier this strategy provides.
  var capability: IsolationCapability { get }

  /// Executes `body` with crash detection and returns the outcome.
  ///
  /// For passthrough and thread-based strategies, `body` is invoked directly.
  /// For subprocess strategies, this method provides a fallback path.
  ///
  /// - Parameter body: A `@Sendable` closure that runs the property predicate and
  ///   returns `true` on pass, `false` on failure.
  /// - Returns: An `IsolationResult` describing the outcome.
  func execute(body: @Sendable () -> Bool) async -> IsolationResult
}

// MARK: - IsolationStrategyFactory

/// A namespace for creating `IsolationStrategy` instances from an `IsolationCapability`.
///
/// Call `IsolationStrategyFactory.strategy(for:)` to obtain the correct backend
/// for the current platform. Real backends (`PosixSpawnIsolation`, `ThreadIsolation`)
/// are introduced in plans 02 and 03; this factory returns a `PassthroughIsolation`
/// for all tiers until those implementations land.
public enum IsolationStrategyFactory {

  /// Returns the isolation strategy appropriate for the given capability.
  ///
  /// - Parameter capability: The capability tier to match.
  /// - Returns: An `IsolationStrategy` for the tier. Returns `PassthroughIsolation`
  ///   until real backends are implemented in subsequent plans.
  public static func strategy(for capability: IsolationCapability) -> any IsolationStrategy {
    // Real PosixSpawnIsolation and ThreadIsolation will be substituted in plans 02 and 03.
    // For now every tier returns PassthroughIsolation so the pattern compiles and wires up.
    PassthroughIsolation()
  }
}

// MARK: - PassthroughIsolation

/// A no-op isolation strategy that runs the test body in-process with no crash detection.
///
/// This is a temporary placeholder until `PosixSpawnIsolation` (plan 02) and
/// `ThreadIsolation` (plan 03) are implemented. It enables the strategy pattern
/// to compile and function end-to-end using the `.none` capability tier.
struct PassthroughIsolation: IsolationStrategy {

  var capability: IsolationCapability { .none }

  func execute(body: @Sendable () -> Bool) async -> IsolationResult {
    let passed = body()
    return passed ? .success : .failure(reason: "Property predicate returned false")
  }
}
