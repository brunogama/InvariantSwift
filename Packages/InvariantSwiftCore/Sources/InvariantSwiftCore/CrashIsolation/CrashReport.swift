// MARK: - CrashReport

/// A structured crash diagnostic produced by an isolation strategy.
///
/// `CrashReport` captures everything needed to reproduce and diagnose a crash
/// found during property-based testing: the signal, the counterexample that
/// triggered the crash, the minimally-shrunk input, and provenance information
/// describing which isolation mechanism detected the crash.
///
/// - Note: `T` must be `Sendable` because crash reports can cross actor boundaries
///   when collected from isolation workers.
public struct CrashReport<T: Sendable>: Sendable {

  // MARK: Stored Properties

  /// The UNIX signal number that caused the crash.
  ///
  /// Common values: 4 (SIGILL), 6 (SIGABRT), 10 (SIGBUS), 11 (SIGSEGV).
  public let signal: Int32

  /// The input value that first triggered the crash (before shrinking).
  public let counterexample: T

  /// The minimal input that still reproduces the crash after shrinking.
  public let shrunkCounterexample: T

  /// Raw stderr output captured from the crash context.
  ///
  /// Contains assertion messages, precondition failure text, and similar
  /// diagnostic output emitted before the crash.
  public let stderr: String

  /// Stack frames captured at the time of the crash.
  ///
  /// May be empty if backtrace collection was not possible.
  public let backtrace: [String]

  /// Whether the backtrace contains human-readable function names.
  ///
  /// When `false`, frames contain raw addresses that require `atos` or a
  /// symbolication tool to resolve.
  public let isSymbolicated: Bool

  /// Which isolation mechanism caught the crash.
  public let isolationMechanism: IsolationMechanism

  // MARK: Computed Properties

  /// Human-readable name for the signal number.
  public var signalName: String {
    switch signal {
    case 4: return "SIGILL"
    case 6: return "SIGABRT"
    case 10: return "SIGBUS"
    case 11: return "SIGSEGV"
    default: return "Signal \(signal)"
    }
  }

  // MARK: Initializer

  /// Creates a `CrashReport` with all required diagnostic fields.
  ///
  /// - Parameters:
  ///   - signal: UNIX signal number (e.g. `SIGABRT` = 6).
  ///   - counterexample: The original crashing input before shrinking.
  ///   - shrunkCounterexample: The minimal crashing input after shrinking.
  ///   - stderr: Raw stderr text captured during the crash.
  ///   - backtrace: Stack frames (may be empty).
  ///   - isSymbolicated: Whether frames have been resolved to function names.
  ///   - isolationMechanism: Which mechanism detected the crash.
  public init(
    signal: Int32,
    counterexample: T,
    shrunkCounterexample: T,
    stderr: String,
    backtrace: [String],
    isSymbolicated: Bool,
    isolationMechanism: IsolationMechanism
  ) {
    self.signal = signal
    self.counterexample = counterexample
    self.shrunkCounterexample = shrunkCounterexample
    self.stderr = stderr
    self.backtrace = backtrace
    self.isSymbolicated = isSymbolicated
    self.isolationMechanism = isolationMechanism
  }

  // MARK: Formatted Output

  /// Returns a human-readable multi-line crash report.
  ///
  /// Includes signal information, isolation mechanism, counterexample,
  /// shrunk counterexample, and (if available) the backtrace and stderr.
  ///
  /// - Returns: A formatted string suitable for printing or logging.
  public func formatted() -> String {
    var lines: [String] = [
      "=== Crash Report ===",
      "Signal: \(signalName) (\(signal))",
      "Isolation: \(isolationMechanism)",
      "Counterexample: \(counterexample)",
      "Shrunk to: \(shrunkCounterexample)",
    ]

    if !backtrace.isEmpty {
      lines.append("Backtrace\(isSymbolicated ? "" : " (unsymbolicated)"):")
      lines.append(contentsOf: backtrace.map { "  \($0)" })
    }

    if !stderr.isEmpty {
      lines.append("Stderr:")
      lines.append(
        contentsOf: stderr.split(separator: "\n", omittingEmptySubsequences: false)
          .map { "  \($0)" }
      )
    }

    lines.append("====================")
    return lines.joined(separator: "\n")
  }

  // MARK: - IsolationMechanism

  /// Identifies which crash-isolation mechanism produced this report.
  ///
  /// Provenance helps users understand the reliability of the diagnostic:
  /// subprocess isolation captures the crash fully outside the test process,
  /// while thread-based isolation captures it within the same process address space.
  public enum IsolationMechanism: Sendable, CustomStringConvertible {

    /// Crash detected by monitoring a `posix_spawn` child process.
    ///
    /// The child's exit status included `WIFSIGNALED`, confirming a clean,
    /// out-of-process crash capture.
    case posixSpawnSubprocess

    /// Crash detected by a signal handler installed on a dedicated thread.
    ///
    /// Used on iOS physical devices where `posix_spawn` is sandbox-restricted.
    /// The crash is caught in-process, so heap/stack state may be partially corrupt.
    case threadSignalHandler

    // MARK: CustomStringConvertible

    public var description: String {
      switch self {
      case .posixSpawnSubprocess:
        return "posixSpawnSubprocess (out-of-process via WIFSIGNALED)"

      case .threadSignalHandler:
        return "threadSignalHandler (in-process signal handler)"
      }
    }
  }
}

// MARK: - Equatable

extension CrashReport: Equatable where T: Equatable {
  public static func == (lhs: CrashReport<T>, rhs: CrashReport<T>) -> Bool {
    lhs.signal == rhs.signal
      && lhs.counterexample == rhs.counterexample
      && lhs.shrunkCounterexample == rhs.shrunkCounterexample
      && lhs.stderr == rhs.stderr
      && lhs.backtrace == rhs.backtrace
      && lhs.isSymbolicated == rhs.isSymbolicated
      && lhs.isolationMechanism == rhs.isolationMechanism
  }
}

// MARK: - IsolationMechanism Equatable

extension CrashReport.IsolationMechanism: Equatable {}
