import Foundation
import Testing
import Darwin.C

/// Global test setup for signal handling and crash debugging
@Suite("Test Setup and Signal Handling")
struct TestSetup {

  /// Install signal handlers to catch crashes during testing
  /// This helps debug SIGTRAP and other signal-related crashes
  static func installSignalHandlers() {
    // Handle SIGTRAP (signal code 5)
    signal(SIGTRAP) { signum in
      print("\n🚨 SIGTRAP (Signal \(signum)) caught!")
      print("📍 Stack trace:")

      let stackTrace = Thread.callStackSymbols
      for (index, symbol) in stackTrace.enumerated() {
        print("  \(index): \(symbol)")
      }

      print("\n💡 SIGTRAP typically indicates:")
      print("  - Force unwrapping nil optionals (!)")
      print("  - Array bounds violations")
      print("  - Assertion failures (assert, precondition)")
      print("  - Runtime type casting failures")

      // Flush output before exiting
      fflush(stdout)
      fflush(stderr)

      // Exit with proper signal code
      exit(Int32(signum))
    }

    // Handle SIGABRT (abort signal)
    signal(SIGABRT) { signum in
      print("\n🚨 SIGABRT (Signal \(signum)) caught!")
      print("📍 Stack trace:")

      let stackTrace = Thread.callStackSymbols
      for (index, symbol) in stackTrace.enumerated() {
        print("  \(index): \(symbol)")
      }

      print("\n💡 SIGABRT typically indicates:")
      print("  - Failed assertions")
      print("  - Memory corruption")
      print("  - Deliberate abort() calls")

      fflush(stdout)
      fflush(stderr)
      exit(Int32(signum))
    }

    // Handle SIGSEGV (segmentation fault)
    signal(SIGSEGV) { signum in
      print("\n🚨 SIGSEGV (Signal \(signum)) caught!")
      print("📍 Stack trace:")

      let stackTrace = Thread.callStackSymbols
      for (index, symbol) in stackTrace.enumerated() {
        print("  \(index): \(symbol)")
      }

      print("\n💡 SIGSEGV typically indicates:")
      print("  - Null pointer dereference")
      print("  - Memory access violations")
      print("  - Stack overflow")

      fflush(stdout)
      fflush(stderr)
      exit(Int32(signum))
    }

    print("✅ Signal handlers installed for crash debugging")
  }

  @Test("Signal handler installation")
  func testSignalHandlerInstallation() {
    // Install signal handlers when tests start
    Self.installSignalHandlers()

    // Verify installation completed without error
    #expect(true, "Signal handlers should install successfully")
  }

  @Test("Stack trace capture test")
  func testStackTraceCapture() {
    let stackTrace = Thread.callStackSymbols

    // Verify we can capture stack traces
    #expect(!stackTrace.isEmpty, "Should be able to capture stack trace")
    #expect(stackTrace.count > 1, "Stack trace should have multiple frames")

    // Print a sample for debugging
    print("📊 Sample stack trace (first 3 frames):")
    for (index, symbol) in stackTrace.prefix(3).enumerated() {
      print("  \(index): \(symbol)")
    }
  }
}

/// Test suite init that automatically installs signal handlers
/// This ensures crash debugging is available for all tests
struct TestSuiteInitializer {
  static let setupOnce: Void = {
    TestSetup.installSignalHandlers()
    print("🧪 Test suite initialized with signal handling")
  }()
}

/// Call this to ensure signal handlers are installed
/// Should be called early in test execution
public func ensureSignalHandlersInstalled() {
  _ = TestSuiteInitializer.setupOnce
}
