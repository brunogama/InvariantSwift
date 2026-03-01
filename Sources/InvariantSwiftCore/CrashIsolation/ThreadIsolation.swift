// Foundation is imported for Thread — the high-level thread abstraction that
// avoids raw pthread_t variables, which trigger a Swift 6.2 SendNonSendable
// compiler bug (https://github.com/swiftlang/swift/issues/<rdar://...>).
import Foundation
import Dispatch

#if canImport(Darwin)
import Darwin

// MARK: - ThreadIsolation

/// An isolation strategy that runs each test iteration on a dedicated thread.
///
/// A `@convention(c)` signal handler for SIGABRT/SIGSEGV/SIGILL/SIGBUS is
/// installed on the child thread. If the test body causes a crash the handler
/// records the signal number and terminates only the child thread via
/// `pthread_exit`. The parent thread survives and reads the crash signal.
///
/// This strategy is selected automatically on iOS physical devices where
/// `posix_spawn` is blocked by the sandbox.
public struct ThreadIsolation: IsolationStrategy, Sendable {

  // MARK: IsolationStrategy

  public var capability: IsolationCapability { .threadBased }

  /// Executes `body` on a dedicated thread with crash-signal detection.
  ///
  /// The thread is started on a global DispatchQueue worker; the calling
  /// cooperative task suspends until the thread signals completion.
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

// MARK: - ThreadedRunner

/// Namespace for the synchronous, Foundation-Thread–based runner.
///
/// All code in this enum is called from a DispatchQueue worker — it may block freely.
private enum ThreadedRunner {

  /// Runs `body` on a new Foundation.Thread with signal handlers installed.
  ///
  /// Uses a DispatchSemaphore for rendezvous (avoids raw pthread_t variables
  /// which trigger a Swift 6.2 SendNonSendable compiler crash).
  static func run(body: @escaping @Sendable () -> Bool) -> IsolationResult {
    let sema = DispatchSemaphore(value: 0)
    let resultBox = ResultBox()

    let thread = Thread {
      let crashSignals: [Int32] = [SIGABRT, SIGSEGV, SIGILL, SIGBUS]
      let previousHandlers = UnsafeMutablePointer<sigaction>.allocate(capacity: crashSignals.count)
      defer { previousHandlers.deallocate() }

      // Install crash signal handlers.
      let sigHandler: (@convention(c) (Int32) -> Void) = { sig in
        Self.crashSignal = sig
        Self.doneSema?.signal()
        pthread_exit(nil)
      }
      var newAction = sigaction()
      newAction.__sigaction_u.__sa_handler = sigHandler
      sigemptyset(&newAction.sa_mask)
      newAction.sa_flags = 0
      for (index, sig) in crashSignals.enumerated() {
        sigaction(sig, &newAction, previousHandlers.advanced(by: index))
      }

      // Store semaphore for signal handler to signal.
      Self.doneSema = sema
      Self.crashSignal = 0

      // Execute the test body.
      resultBox.passed = body()

      // Restore signal handlers.
      for (index, sig) in crashSignals.enumerated() {
        var old = previousHandlers[index]
        sigaction(sig, &old, nil)
      }

      Self.doneSema = nil
      sema.signal()
    }
    thread.start()
    sema.wait()

    let crashSig = Self.crashSignal
    if crashSig != 0 {
      return .crashed(
        signal: crashSig,
        stderr: "",
        backtrace: captureBacktrace(),
        isSymbolicated: false
      )
    }
    return resultBox.passed ? .success : .failure(reason: "Property predicate returned false")
  }

  // MARK: - Thread-local crash state

  /// Written by the signal handler; read by the parent after the semaphore fires.
  nonisolated(unsafe) static var crashSignal: Int32 = 0

  /// The semaphore for the currently active thread run (nil when idle).
  nonisolated(unsafe) static var doneSema: DispatchSemaphore?
}

// MARK: - ResultBox

/// A reference-type wrapper for the bool result that crosses the Thread boundary.
private final class ResultBox: @unchecked Sendable {
  var passed: Bool = false
}

// MARK: - Best-Effort Backtrace

/// Captures a best-effort backtrace using Darwin's `backtrace` + `backtrace_symbols`.
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
