import Testing
@testable import InvariantSwiftCore

/// Tests for CrashReport<T> struct and IsolationMechanism enum.
@Suite("CrashReport Tests")
struct CrashReportTests {

  // MARK: - Initializer

  @Test("CrashReport can be created with all fields")
  func createCrashReport() {
    let report = CrashReport<Int>(
      signal: 6,
      counterexample: 42,
      shrunkCounterexample: 0,
      stderr: "some error text",
      backtrace: ["frame0", "frame1"],
      isSymbolicated: true,
      isolationMechanism: .posixSpawnSubprocess
    )
    #expect(report.signal == 6)
    #expect(report.counterexample == 42)
    #expect(report.shrunkCounterexample == 0)
    #expect(report.stderr == "some error text")
    #expect(report.backtrace == ["frame0", "frame1"])
    #expect(report.isSymbolicated == true)
    #expect(report.isolationMechanism == .posixSpawnSubprocess)
  }

  @Test("CrashReport can be created with empty backtrace and stderr")
  func createMinimalCrashReport() {
    let report = CrashReport<String>(
      signal: 11,
      counterexample: "hello",
      shrunkCounterexample: "",
      stderr: "",
      backtrace: [],
      isSymbolicated: false,
      isolationMechanism: .threadSignalHandler
    )
    #expect(report.signal == 11)
    #expect(report.backtrace.isEmpty)
    #expect(report.stderr.isEmpty)
  }

  // MARK: - signalName

  @Test("signalName returns SIGABRT for signal 6")
  func signalNameSIGABRT() {
    let report = makeReport(signal: 6)
    #expect(report.signalName == "SIGABRT")
  }

  @Test("signalName returns SIGSEGV for signal 11")
  func signalNameSIGSEGV() {
    let report = makeReport(signal: 11)
    #expect(report.signalName == "SIGSEGV")
  }

  @Test("signalName returns SIGILL for signal 4")
  func signalNameSIGILL() {
    let report = makeReport(signal: 4)
    #expect(report.signalName == "SIGILL")
  }

  @Test("signalName returns SIGBUS for signal 10")
  func signalNameSIGBUS() {
    let report = makeReport(signal: 10)
    #expect(report.signalName == "SIGBUS")
  }

  @Test("signalName returns Signal N for unknown signal")
  func signalNameUnknown() {
    let report = makeReport(signal: 99)
    #expect(report.signalName == "Signal 99")
  }

  @Test("signalName returns Signal N for signal 9 (SIGKILL)")
  func signalNameSIGKILL() {
    let report = makeReport(signal: 9)
    #expect(report.signalName == "Signal 9")
  }

  // MARK: - formatted()

  @Test("formatted() output contains signal name")
  func formattedContainsSignalName() {
    let report = makeReport(signal: 6)
    let output = report.formatted()
    #expect(output.contains("SIGABRT"))
  }

  @Test("formatted() output contains isolation mechanism")
  func formattedContainsMechanism() {
    let report = makeReport(mechanism: .posixSpawnSubprocess)
    let output = report.formatted()
    #expect(output.contains("posixSpawnSubprocess"))
  }

  @Test("formatted() output contains counterexample")
  func formattedContainsCounterexample() {
    let report = CrashReport<Int>(
      signal: 6,
      counterexample: 12345,
      shrunkCounterexample: 0,
      stderr: "",
      backtrace: [],
      isSymbolicated: false,
      isolationMechanism: .posixSpawnSubprocess
    )
    let output = report.formatted()
    #expect(output.contains("12345"))
  }

  @Test("formatted() output contains backtrace when non-empty")
  func formattedContainsBacktrace() {
    let report = CrashReport<Int>(
      signal: 6,
      counterexample: 0,
      shrunkCounterexample: 0,
      stderr: "",
      backtrace: ["main + 32"],
      isSymbolicated: true,
      isolationMechanism: .posixSpawnSubprocess
    )
    let output = report.formatted()
    #expect(output.contains("main + 32"))
  }

  @Test("formatted() output contains stderr when non-empty")
  func formattedContainsStderr() {
    let report = CrashReport<Int>(
      signal: 6,
      counterexample: 0,
      shrunkCounterexample: 0,
      stderr: "Fatal error: file.swift:10",
      backtrace: [],
      isSymbolicated: false,
      isolationMechanism: .threadSignalHandler
    )
    let output = report.formatted()
    #expect(output.contains("Fatal error: file.swift:10"))
  }

  @Test("formatted() omits backtrace section when empty")
  func formattedOmitsEmptyBacktrace() {
    let report = makeReport(signal: 11)
    let output = report.formatted()
    #expect(!output.contains("Backtrace"))
  }

  // MARK: - IsolationMechanism

  @Test("IsolationMechanism.posixSpawnSubprocess description is non-empty")
  func posixSpawnDescription() {
    let desc = CrashReport<Int>.IsolationMechanism.posixSpawnSubprocess.description
    #expect(!desc.isEmpty)
  }

  @Test("IsolationMechanism.threadSignalHandler description is non-empty")
  func threadSignalHandlerDescription() {
    let desc = CrashReport<Int>.IsolationMechanism.threadSignalHandler.description
    #expect(!desc.isEmpty)
  }

  @Test("IsolationMechanism descriptions are distinct")
  func mechanismDescriptionsAreDistinct() {
    let subprocess = CrashReport<Int>.IsolationMechanism.posixSpawnSubprocess.description
    let thread = CrashReport<Int>.IsolationMechanism.threadSignalHandler.description
    #expect(subprocess != thread)
  }

  // MARK: - Equatable

  @Test("CrashReport Equatable: equal reports are equal")
  func equatableEqual() {
    let r1 = makeReport(signal: 6)
    let r2 = makeReport(signal: 6)
    #expect(r1 == r2)
  }

  @Test("CrashReport Equatable: different signal is not equal")
  func equatableDifferentSignal() {
    let r1 = makeReport(signal: 6)
    let r2 = makeReport(signal: 11)
    #expect(r1 != r2)
  }

  @Test("CrashReport Equatable: different mechanism is not equal")
  func equatableDifferentMechanism() {
    let r1 = makeReport(mechanism: .posixSpawnSubprocess)
    let r2 = makeReport(mechanism: .threadSignalHandler)
    #expect(r1 != r2)
  }

  // MARK: - Sendable (compile-time check)

  @Test("CrashReport is Sendable across actor boundaries")
  func sendableConformance() async {
    let report = makeReport(signal: 6)
    // Sending across actor boundary verifies Sendable conformance at the type system level.
    let transferred = await Task.detached {
      report  // crosses actor boundary
    }.value
    #expect(transferred.signal == 6)
  }

  // MARK: - Helpers

  private func makeReport(
    signal: Int32 = 6,
    mechanism: CrashReport<Int>.IsolationMechanism = .posixSpawnSubprocess
  ) -> CrashReport<Int> {
    CrashReport<Int>(
      signal: signal,
      counterexample: 0,
      shrunkCounterexample: 0,
      stderr: "",
      backtrace: [],
      isSymbolicated: false,
      isolationMechanism: mechanism
    )
  }
}
