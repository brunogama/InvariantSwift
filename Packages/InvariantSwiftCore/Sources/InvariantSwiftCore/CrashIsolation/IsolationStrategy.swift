// Foundation is imported for FileManager, ProcessInfo, and NSString path manipulation
// used in IsolationStrategyFactory.discoverHelperPath(). InvariantSwiftCore already
// depends on Foundation throughout, so this adds no new dependency.
import Foundation

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
  func execute(body: @escaping @Sendable () -> Bool) async -> IsolationResult
}

// MARK: - IsolationStrategyFactory

/// A namespace for creating `IsolationStrategy` instances from an `IsolationCapability`.
///
/// Call `IsolationStrategyFactory.strategy(for:)` to obtain the correct backend
/// for the current runtime environment. Helper path discovery uses `FileManager`
/// (Foundation) since `InvariantSwiftCore` already depends on Foundation.
public enum IsolationStrategyFactory {

  /// Subprocess timeout in seconds used when constructing `PosixSpawnIsolation`.
  private static let defaultTimeout: Double = 5.0

  /// Returns the isolation strategy appropriate for the given capability.
  ///
  /// - `.fullSubprocess`: Returns `PosixSpawnIsolation` when the helper binary is
  ///   discoverable, or `PassthroughIsolation` when it is not.
  /// - `.threadBased`: Returns `ThreadIsolation` on Darwin platforms.
  /// - `.none`: Returns `PassthroughIsolation`.
  ///
  /// - Parameter capability: The capability tier to match.
  /// - Returns: An `IsolationStrategy` appropriate for the tier.
  public static func strategy(for capability: IsolationCapability) -> any IsolationStrategy {
    switch capability {
    case .fullSubprocess:
      #if canImport(Darwin)
      if let path = discoverHelperPath() {
        return PosixSpawnIsolation(helperPath: path, timeout: defaultTimeout)
      }
      // Helper not found — fall through to passthrough.
      #endif
      return PassthroughIsolation()

    case .threadBased:
      #if canImport(Darwin)
      return ThreadIsolation()
      #else
      return PassthroughIsolation()
      #endif

    case .none:
      return PassthroughIsolation()
    }
  }

  // MARK: - Helper Binary Discovery

  /// Searches common locations for the `PropertyTestHelper` executable.
  ///
  /// Checks (in order):
  /// 1. Same directory as the currently running process (`argv[0]` parent)
  /// 2. `.build/debug/PropertyTestHelper` (SPM debug build)
  /// 3. `.build/release/PropertyTestHelper` (SPM release build)
  ///
  /// - Returns: The absolute path of the first executable match, or `nil`.
  static func discoverHelperPath() -> String? {
    let binaryName = "PropertyTestHelper"

    var candidates: [String] = []

    // Sibling of the current executable.
    if let executablePath = ProcessInfo.processInfo.arguments.first {
      let executableDir = (executablePath as NSString).deletingLastPathComponent
      candidates.append((executableDir as NSString).appendingPathComponent(binaryName))
    }

    // Relative SPM build directories (works when running from the package root).
    candidates.append(".build/debug/\(binaryName)")
    candidates.append(".build/release/\(binaryName)")

    return candidates.first {
      FileManager.default.isExecutableFile(atPath: $0)
    }
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

  func execute(body: @escaping @Sendable () -> Bool) async -> IsolationResult {
    let passed = body()
    return passed ? .success : .failure(reason: "Property predicate returned false")
  }
}
