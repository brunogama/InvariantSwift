import Darwin

// MARK: - IsolationCapability

/// Describes the level of crash isolation available at runtime.
///
/// Call `IsolationCapability.current` to obtain the cached capability for the
/// running platform, or `IsolationCapability.detect()` to force a fresh probe.
///
/// - Note: Probing spawns `/usr/bin/true` via `posix_spawn`; `current` caches
///   the result on first access to avoid repeated syscalls.
public enum IsolationCapability: Sendable, CustomStringConvertible {

  /// Full crash isolation via a `posix_spawn` child process.
  ///
  /// Available on macOS and iOS Simulator where `posix_spawn` is permitted.
  case fullSubprocess

  /// Thread-based signal isolation using a dedicated signal-catching thread.
  ///
  /// Used on iOS physical devices where `posix_spawn` is restricted by the
  /// sandbox. Provides best-effort isolation within the host process.
  case threadBased

  /// No crash isolation — tests run in-process with no protection.
  ///
  /// The test runner may terminate on a crash. Used on platforms where
  /// neither subprocess nor thread-based isolation is available.
  case none

  // MARK: CustomStringConvertible

  public var description: String {
    switch self {
    case .fullSubprocess:
      return "fullSubprocess (posix_spawn child process)"

    case .threadBased:
      return "threadBased (pthread signal handler)"

    case .none:
      return "none (in-process, no isolation)"
    }
  }

  // MARK: Public API

  /// Returns the cached isolation capability for the current runtime environment.
  ///
  /// The capability is determined on first access and reused for subsequent calls.
  public static var current: Self { CachedCapability.value }

  /// Probes the runtime environment and returns the best available isolation capability.
  ///
  /// On macOS the answer is always `.fullSubprocess` (compile-time short-circuit).
  /// On other Darwin platforms (e.g. iOS) a lightweight `posix_spawn` probe is
  /// performed; failure indicates sandbox restrictions and falls back to `.threadBased`.
  /// On non-Darwin platforms `.none` is returned.
  ///
  /// - Returns: The best `IsolationCapability` available at runtime.
  public static func detect() -> Self {
    #if os(macOS)
    return .fullSubprocess
    #elseif canImport(Darwin)
    return probeSubprocessAvailability() ? .fullSubprocess : .threadBased
    #else
    return .none
    #endif
  }

  // MARK: Private

  /// Lazily cached capability — computed the first time `current` is accessed.
  private enum CachedCapability {
    static let value = detect()
  }

  /// Attempts to spawn `/usr/bin/true` via `posix_spawn` to determine whether
  /// subprocess creation is permitted by the sandbox.
  ///
  /// - Returns: `true` if `posix_spawn` succeeds, `false` on permission error.
  private static func probeSubprocessAvailability() -> Bool {
    // Build argv: ["/usr/bin/true", nil]
    let path = "/usr/bin/true"
    let arg0 = strdup(path)
    defer { free(arg0) }

    var argv: [UnsafeMutablePointer<CChar>?] = [arg0, nil]
    var pid: pid_t = 0

    let spawnResult = posix_spawn(&pid, path, nil, nil, &argv, nil)
    guard spawnResult == 0 else {
      return false
    }

    // Reap the child, retrying on EINTR.
    var status: Int32 = 0
    var waitResult: pid_t
    repeat {
      waitResult = waitpid(pid, &status, 0)
    } while waitResult == -1 && errno == EINTR

    guard waitResult == pid else {
      return false
    }

    let wstatus = status & 0x7f
    guard wstatus == 0 else {
      return false
    }

    let exitCode = (status >> 8) & 0xff
    return exitCode == 0
  }
}
