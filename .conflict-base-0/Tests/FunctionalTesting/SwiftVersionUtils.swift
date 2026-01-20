// swiftlint:disable:this file_name

/// Utilities for detecting Swift version and beta/pre-release SDKs.
///
/// **Note**: The `sigtrap_capture.py` script now handles post-test cleanup crashes
/// gracefully (detecting when all tests pass before a runtime crash). This utility
/// is kept for future use but proactive test skipping is no longer needed.

import Foundation
import XCTest

// MARK: - macOS Version Info

/// Represents a macOS version with major, minor, and patch components.
public struct MacOSVersion: Sendable, Equatable {
  public let major: Int
  public let minor: Int
  public let patch: Int

  public init(major: Int, minor: Int, patch: Int) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }
}

// MARK: - Swift Version Detection

/// Provides utilities for detecting Swift version and SDK information at runtime.
public enum SwiftVersionUtils {
  /// Returns true if running on a beta or pre-release SDK.
  ///
  /// Pre-release macOS SDKs may have ABI compatibility issues with certain Swift features.
  /// - macOS 26.2 is the current stable release (Dec 2025)
  /// - macOS 26.3+ is beta (expected Feb 2026)
  public static var isPreReleaseSDK: Bool {
    let version = macOSVersion

    // macOS 26.3+ is currently beta
    if version.major == 26 && version.minor >= 3 {
      return true
    }

    // Future major versions we haven't seen yet
    if version.major > 26 {
      return true
    }

    return false
  }

  /// Returns true if the current environment is a stable release.
  public static var isStableRelease: Bool {
    !isPreReleaseSDK
  }

  /// The current macOS version.
  public static var macOSVersion: MacOSVersion {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return MacOSVersion(
      major: version.majorVersion,
      minor: version.minorVersion,
      patch: version.patchVersion
    )
  }
}

// MARK: - Test Skipping Helpers

/// Trait for marking tests that should be skipped on pre-release Swift/SDK versions.
public struct SkipOnPreRelease: CustomStringConvertible {
  public let reason: String

  public init(_ reason: String = "Test skipped on pre-release SDK due to known ABI issues") {
    self.reason = reason
  }

  public var description: String { reason }

  /// Returns true if the test should be skipped.
  public var shouldSkip: Bool {
    SwiftVersionUtils.isPreReleaseSDK
  }
}

/// Check if tests should skip due to pre-release environment.
/// Use at the beginning of tests that are known to crash on beta SDKs.
///
/// Example:
/// ```swift
/// func testSomeFeature() throws {
///     try skipOnPreReleaseSDK()
///     // rest of test...
/// }
/// ```
public func skipOnPreReleaseSDK(
  reason: String = "Skipping due to known ABI issues on pre-release SDK"
) throws {
  if SwiftVersionUtils.isPreReleaseSDK {
    throw XCTSkip(reason)
  }
}
