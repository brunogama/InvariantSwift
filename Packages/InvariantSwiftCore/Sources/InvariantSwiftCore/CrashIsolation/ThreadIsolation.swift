// Foundation is imported for Thread — the high-level thread abstraction that
// avoids raw pthread_t variables, which trigger a Swift 6.2 SendNonSendable
// compiler bug. Thread provides identical semantics without exposing pthread_t.
import Foundation
import Dispatch

#if canImport(Darwin)
import Darwin

// MARK: - ThreadIsolation

/// An isolation strategy that runs each test iteration on a dedicated thread.
///
/// A `@convention(c)` signal handler for crash signals is installed
/// on the child thread. If the test body causes a crash the handler writes the signal
/// number to a pre-allocated pipe (async-signal-safe per POSIX) and calls `pthread_exit`
/// to terminate only the child thread. On normal exit the thread writes a negative
/// sentinel to the same pipe that encodes pass or fail. The parent blocks on `read(2)`
/// to learn the outcome.
///
/// Signal handlers are process-wide, not thread-local. This implementation therefore
/// serializes every threaded isolation run behind a single lock so only one handler
/// installation is active at a time.
///
/// This strategy is selected automatically on iOS physical devices where
/// `posix_spawn` is blocked by the sandbox.
public struct ThreadIsolation: IsolationStrategy, Sendable {

  // MARK: IsolationStrategy

  public var capability: IsolationCapability { .threadBased }

  /// Executes `body` on a dedicated thread with crash-signal detection.
  ///
  /// The blocking `read(2)` runs on a DispatchQueue worker so the calling
  /// cooperative task suspends without blocking the cooperative thread pool.
  ///
  /// - Parameter body: The property predicate; returns `true` on pass.
  /// - Returns: `.success`, `.failure`, or `.crashed` based on the outcome.
  public func execute(body: @escaping @Sendable () -> Bool) async -> IsolationResult {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let result = ThreadedRunner.run(body: body)
        continuation.resume(returning: result)
      }
    }
  }
}

// MARK: - Async-Signal-Safe Global State

/// Write end of the unified outcome pipe, published for the signal handler.
///
/// Access is serialized by `ThreadIsolationCoordinator.executionLock`: each run
/// sets this before starting the worker thread and resets it to `-1` only after
/// the worker outcome pipe has been consumed. `nonisolated(unsafe)` satisfies
/// Swift 6 strict concurrency for this async-signal-safe bridge.
nonisolated(unsafe) private var gOutcomePipeWriteFD: Int32 = -1

/// Serializes thread-isolation runs so the process-wide signal handlers and
/// global outcome pipe fd are never active for multiple runs at once.
private enum ThreadIsolationCoordinator {
  static let executionLock = DispatchSemaphore(value: 1)
}

/// Sentinels written to the pipe on a normal (non-crash) exit.
///
/// Fatal signals are always positive. Negative values therefore remain reserved for
/// normal pass/fail completion and avoid any shared mutable state across threads.
private let kPassedExitSentinel: Int32 = -1
private let kFailedExitSentinel: Int32 = -2

/// Async-signal-safe crash handler.
///
/// POSIX guarantees `write(2)` and `pthread_exit(3)` are async-signal-safe.
/// This function MUST NOT call Swift ARC, ObjC messaging, or allocate memory.
private func crashSignalHandler(_ sig: Int32) {
  var s = sig
  _ = Darwin.write(gOutcomePipeWriteFD, &s, MemoryLayout<Int32>.size)
  pthread_exit(nil)
}

// MARK: - ThreadedRunner

/// Synchronous, Foundation-Thread–based runner.
///
/// All code in this enum is called from a DispatchQueue worker and may block freely.
private enum ThreadedRunner {

  private static let crashSignals: [Int32] = [SIGABRT, SIGBUS, SIGILL, SIGSEGV, SIGTRAP]

  /// Runs `body` on a new Foundation.Thread with async-signal-safe crash detection.
  ///
  /// IPC protocol: the outcome pipe carries exactly 4 bytes.
  /// - `-1` (`kPassedExitSentinel`) → normal success.
  /// - `-2` (`kFailedExitSentinel`) → normal predicate failure.
  /// - Positive value → crash; value is the received signal number.
  static func run(body: @escaping @Sendable () -> Bool) -> IsolationResult {
    ThreadIsolationCoordinator.executionLock.wait()
    defer { ThreadIsolationCoordinator.executionLock.signal() }

    // Create outcome pipe: [0] = read end (parent), [1] = write end (child or handler).
    var pipeFDs: [Int32] = [-1, -1]
    guard Darwin.pipe(&pipeFDs) == 0 else {
      return .failure(reason: "Thread isolation: pipe creation failed (errno \(errno))")
    }
    let readFD = pipeFDs[0]
    let writeFD = pipeFDs[1]

    // Non-blocking write end so the signal handler never stalls.
    _ = fcntl(writeFD, F_SETFL, O_NONBLOCK)

    // Publish write FD before launching the thread.
    gOutcomePipeWriteFD = writeFD

    let thread = Thread {
      let prevHandlers = UnsafeMutablePointer<sigaction>.allocate(capacity: crashSignals.count)
      defer { prevHandlers.deallocate() }
      installCrashHandlers(saving: prevHandlers)

      let passed = body()

      // Normal exit: restore handlers, then write the final pass/fail sentinel.
      restoreCrashHandlers(from: prevHandlers)
      var sentinel = passed ? kPassedExitSentinel : kFailedExitSentinel
      _ = Darwin.write(writeFD, &sentinel, MemoryLayout<Int32>.size)
    }
    thread.start()

    // Block until 4 bytes arrive (crash signal or normal-exit sentinel).
    var outcome: Int32 = 0
    _ = Darwin.read(readFD, &outcome, MemoryLayout<Int32>.size)

    Darwin.close(readFD)
    Darwin.close(writeFD)
    gOutcomePipeWriteFD = -1

    switch outcome {
    case kPassedExitSentinel:
      return .success

    case kFailedExitSentinel:
      return .failure(reason: "Property predicate returned false")

    default:
      return .crashed(
        signal: outcome,
        stderr: "",
        backtrace: captureBacktrace(),
        isSymbolicated: false
      )
    }
  }

  // MARK: - Signal Handler Lifecycle

  /// Installs `crashSignalHandler` for all crash signals, saving previous handlers.
  private static func installCrashHandlers(
    saving previous: UnsafeMutablePointer<sigaction>
  ) {
    var action = sigaction()
    action.__sigaction_u.__sa_handler = crashSignalHandler
    sigemptyset(&action.sa_mask)
    action.sa_flags = 0
    for (i, sig) in crashSignals.enumerated() {
      sigaction(sig, &action, previous.advanced(by: i))
    }
  }

  /// Restores previously saved signal handlers.
  private static func restoreCrashHandlers(from previous: UnsafeMutablePointer<sigaction>) {
    for (i, sig) in crashSignals.enumerated() {
      var old = previous[i]
      sigaction(sig, &old, nil)
    }
  }
}

// MARK: - Best-Effort Backtrace

/// Captures a best-effort backtrace using Darwin's `backtrace` + `backtrace_symbols`.
///
/// Called on the parent thread after crash detection. `backtrace_symbols` returns
/// a malloc'd array; `free()` is called via `defer` to prevent memory leaks.
private func captureBacktrace() -> [String] {
  let maxFrames = 64
  let buffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: maxFrames)
  defer { buffer.deallocate() }

  let frameCount = backtrace(buffer, Int32(maxFrames))
  guard frameCount > 0, let symbols = backtrace_symbols(buffer, frameCount) else { return [] }
  defer { free(symbols) }

  return (0..<Int(frameCount)).compactMap { index in
    symbols[index].map { String(cString: $0) }
  }
}

#endif  // canImport(Darwin)
