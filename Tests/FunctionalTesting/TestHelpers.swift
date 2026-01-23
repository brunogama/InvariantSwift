import Foundation
import Testing
import InvariantSwiftCore

/// Helper utilities for test environment detection and conditional skipping
enum TestEnvironment {
  /// Returns true if running on a beta macOS version (26.0+)
  static var isBetaMacOS: Bool {
    #if os(macOS)
    let version = ProcessInfo.processInfo.operatingSystemVersion
    // macOS 26 (Tahoe) is the current beta as of 2026
    return version.majorVersion >= 26
    #else
    return false
    #endif
  }

  /// Use with @Test(.enabled(if: TestEnvironment.isNotBetaMacOS))
  /// to skip tests that are unstable on macOS 26 beta
  static var isNotBetaMacOS: Bool { !isBetaMacOS }
}
