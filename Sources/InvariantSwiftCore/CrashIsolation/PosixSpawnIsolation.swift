// Foundation is imported ONLY for JSONEncoder, JSONDecoder, and Data —
// which are unavoidable because the IPC protocol uses Codable.
// No Foundation.Process or Foundation.Pipe is used anywhere in this file.
import Foundation

#if canImport(Darwin)
import Darwin

// MARK: - PosixSpawnIsolation

/// A crash-isolation strategy that spawns a child process via `posix_spawn`.
///
/// Each call to `executeViaSubprocess(request:)` forks a fresh helper process,
/// sends a `PropertyEvaluationRequest` over a stdin pipe, and waits for the
/// child to reply on stdout. If the child terminates due to a signal (crash),
/// the parent survives and returns a `.crashed` result.
///
/// **Protocol conformance:** `execute(body:)` exists for generic protocol usage
/// but provides no subprocess isolation — it calls `body()` in-process. Callers
/// that want crash isolation must use `executeViaSubprocess(request:)` directly.
///
/// **Platform:** macOS and iOS Simulator (any Darwin where `posix_spawn` is permitted).
public struct PosixSpawnIsolation: IsolationStrategy, Sendable {

  // MARK: Properties

  /// Absolute path to the `PropertyTestHelper` executable.
  public let helperPath: String

  /// Maximum wall-clock seconds allowed per subprocess run before `SIGKILL`.
  public let timeout: Double

  // MARK: IsolationStrategy

  public var capability: IsolationCapability { .fullSubprocess }

  /// Fallback protocol conformance — executes `body` in-process with no isolation.
  ///
  /// Prefer `executeViaSubprocess(request:)` for real crash isolation.
  public func execute(body: @escaping @Sendable () -> Bool) async -> IsolationResult {
    let passed = body()
    return passed ? .success : .failure(reason: "Property predicate returned false")
  }

  // MARK: Subprocess Execution

  /// Execute a `PropertyEvaluationRequest` in an isolated child process.
  ///
  /// The child runs `PropertyTestHelper`, receives the request on stdin,
  /// and writes a `PropertyEvaluationResponse` to stdout.
  ///
  /// - Parameter request: The serialised test parameters for this iteration.
  /// - Returns: An `IsolationResult` based on the child's exit status or signal.
  public func executeViaSubprocess(request: PropertyEvaluationRequest) async -> IsolationResult {
    // Encode request — bail early on serialisation failure (not a crash).
    let requestData: Data
    do {
      requestData = try JSONEncoder().encode(request)
    } catch {
      return .failure(reason: "Request encode error: \(error)")
    }

    // Spawn child and obtain parent-side file descriptors.
    let child: ChildProcessFDs
    do {
      child = try spawnChild()
    } catch {
      return .failure(reason: "posix_spawn error: \(error)")
    }

    // Write length-prefixed JSON to child stdin, then close writer.
    var lengthBE = UInt32(requestData.count).bigEndian
    let writeResult = withUnsafeBytes(of: &lengthBE) { buf -> Int32 in
      Darwin.write(child.stdinFD, buf.baseAddress!, 4)
      return Darwin.write(child.stdinFD, Array(requestData), requestData.count) < 0 ? -1 : 0
    }
    Darwin.close(child.stdinFD)

    if writeResult < 0 {
      kill(child.pid, SIGKILL)
      _ = waitForChild(child.pid)
      Darwin.close(child.stdoutFD)
      Darwin.close(child.stderrFD)
      return .failure(reason: "Failed to write request to child stdin")
    }

    // Arm timeout: kill child after `timeout` seconds if still running.
    let pid = child.pid
    let timeoutNS = UInt64(timeout * 1_000_000_000)
    let timeoutTask = Task.detached {
      try? await Task.sleep(nanoseconds: timeoutNS)
      kill(pid, SIGKILL)
    }

    // Wait for child off the cooperative thread pool.
    let termination = await Task.detached(priority: .userInitiated) {
      self.waitForChild(pid)
    }.value

    timeoutTask.cancel()

    // Read stdout / stderr.
    let stdoutData = readAll(from: child.stdoutFD)
    let stderrData = readAll(from: child.stderrFD)

    // Interpret exit status.
    return buildResult(
      termination: termination,
      stdoutData: stdoutData,
      stderrData: stderrData
    )
  }

  // MARK: - Private: Spawn

  /// Outcome of waiting for a child process.
  private enum ChildTermination: Sendable {
    case exited(code: Int32)
    case signaled(signal: Int32)
    case unknown
  }

  /// Parent-side file descriptors returned after a successful spawn.
  private struct ChildProcessFDs {
    let pid: pid_t
    let stdinFD: Int32
    let stdoutFD: Int32
    let stderrFD: Int32
  }

  /// Spawn `helperPath` with three pipes wired to stdin / stdout / stderr.
  ///
  /// On success, closes the child-side pipe ends and returns the parent-side fds.
  /// On failure, closes all fds and throws.
  private func spawnChild() throws -> ChildProcessFDs {
    // pipe[0] = read end, pipe[1] = write end.
    var stdinPipe: [Int32] = [0, 0]
    var stdoutPipe: [Int32] = [0, 0]
    var stderrPipe: [Int32] = [0, 0]

    guard pipe(&stdinPipe) == 0, pipe(&stdoutPipe) == 0, pipe(&stderrPipe) == 0 else {
      closeAll(stdinPipe + stdoutPipe + stderrPipe)
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EINVAL)
    }

    var fileActions = posix_spawn_file_actions_t(bitPattern: 0)
    posix_spawn_file_actions_init(&fileActions)
    defer { posix_spawn_file_actions_destroy(&fileActions) }

    // Child: dup2 read-end of stdinPipe  -> STDIN_FILENO
    posix_spawn_file_actions_adddup2(&fileActions, stdinPipe[0], STDIN_FILENO)
    // Child: dup2 write-end of stdoutPipe -> STDOUT_FILENO
    posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe[1], STDOUT_FILENO)
    // Child: dup2 write-end of stderrPipe -> STDERR_FILENO
    posix_spawn_file_actions_adddup2(&fileActions, stderrPipe[1], STDERR_FILENO)

    // Child: close all pipe ends it inherited (they are now dup'd to std fds).
    posix_spawn_file_actions_addclose(&fileActions, stdinPipe[0])
    posix_spawn_file_actions_addclose(&fileActions, stdinPipe[1])
    posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[0])
    posix_spawn_file_actions_addclose(&fileActions, stdoutPipe[1])
    posix_spawn_file_actions_addclose(&fileActions, stderrPipe[0])
    posix_spawn_file_actions_addclose(&fileActions, stderrPipe[1])

    let arg0 = strdup(helperPath)
    defer { free(arg0) }
    var argv: [UnsafeMutablePointer<CChar>?] = [arg0, nil]

    var pid: pid_t = 0
    let spawnErr = posix_spawn(&pid, helperPath, &fileActions, nil, &argv, nil)

    if spawnErr != 0 {
      closeAll(stdinPipe + stdoutPipe + stderrPipe)
      throw POSIXError(POSIXErrorCode(rawValue: spawnErr) ?? .EINVAL)
    }

    // Parent: close child-side ends.
    Darwin.close(stdinPipe[0])  // child reads from here; parent doesn't need it
    Darwin.close(stdoutPipe[1])  // child writes here; parent doesn't need it
    Darwin.close(stderrPipe[1])  // child writes here; parent doesn't need it

    return ChildProcessFDs(
      pid: pid,
      stdinFD: stdinPipe[1],
      stdoutFD: stdoutPipe[0],
      stderrFD: stderrPipe[0]
    )
  }

  // MARK: - Private: Wait

  private func waitForChild(_ pid: pid_t) -> ChildTermination {
    var status: Int32 = 0
    var result: pid_t
    repeat {
      result = waitpid(pid, &status, 0)
    } while result == -1 && errno == EINTR

    // WIFEXITED / WEXITSTATUS / WIFSIGNALED / WTERMSIG are C macros unavailable in Swift.
    // Inline the Darwin definitions: _WSTATUS(x) = x & 0x7f
    let wstatus = status & 0x7f
    if wstatus == 0 {
      // WIFEXITED: low 7 bits all zero
      let exitCode = (status >> 8) & 0xff  // WEXITSTATUS
      return .exited(code: exitCode)
    }
    if wstatus != 0x7f {
      // WIFSIGNALED: low 7 bits non-zero and not 0x7f (stopped)
      return .signaled(signal: wstatus)  // WTERMSIG
    }
    return .unknown
  }

  // MARK: - Private: I/O

  private func readAll(from fd: Int32) -> Data {
    var buffer = [UInt8](repeating: 0, count: 4096)
    var data = Data()
    while true {
      let n = Darwin.read(fd, &buffer, buffer.count)
      if n <= 0 { break }
      data.append(contentsOf: buffer[..<n])
    }
    Darwin.close(fd)
    return data
  }

  private func closeAll(_ fds: [Int32]) {
    for fd in fds where fd > 0 {
      Darwin.close(fd)
    }
  }

  // MARK: - Private: Result

  private func buildResult(
    termination: ChildTermination,
    stdoutData: Data,
    stderrData: Data
  ) -> IsolationResult {
    switch termination {
    case .signaled(let sig):
      let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
      let frames =
        stderrText
        .components(separatedBy: "\n")
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      return .crashed(signal: sig, stderr: stderrText, backtrace: frames, isSymbolicated: false)

    case .exited(let code):
      guard code == 0 else {
        return .failure(reason: "Helper exited with code \(code)")
      }
      guard
        let response = try? JSONDecoder().decode(PropertyEvaluationResponse.self, from: stdoutData)
      else {
        return .failure(reason: "Failed to decode helper response")
      }
      return response.passed
        ? .success
        : .failure(reason: response.failureReason ?? "Property returned false")

    case .unknown:
      return .failure(reason: "Unexpected child wait status")
    }
  }
}

#endif  // canImport(Darwin)
