import InvariantSwiftCore
import InvariantSwift
import InvariantSwiftAdvanced

/// Enforces a timeout on a property test.
///
/// Use this macro to prevent property tests from hanging in CI environments.
/// If the test exceeds the specified timeout, it fails with a clear timeout message
/// showing both the elapsed time and the configured limit.
///
/// ## Usage
///
/// Basic timeout with seconds:
/// ```swift
/// @Timeout(seconds: 5.0)
/// @PropertyTest
/// func slowProperty(data: [Int]) -> Bool {
///   expensiveComputation(data)
/// }
/// ```
///
/// Using TimeoutDuration enum for more control:
/// ```swift
/// @Timeout(.milliseconds(500))
/// @PropertyTest
/// func fastProperty(n: Int) -> Bool { ... }
/// ```
///
/// Disable timeout for debugging:
/// ```swift
/// @Timeout(.none)
/// @PropertyTest
/// func debugProperty(n: Int) -> Bool { ... }
/// ```
///
/// ## Parameters
///
/// - Parameter seconds: Maximum execution time in seconds
/// - Parameter duration: TimeoutDuration for more control (.seconds, .milliseconds, .none)
///
/// ## Error Reporting
///
/// When a timeout occurs, the failure message includes:
/// - Elapsed time when timeout was triggered
/// - Configured timeout limit
/// - Example: "Property test timed out after 5.2s (limit: 5.0s)"
///
/// ## Implementation Notes
///
/// The timeout is enforced using Swift Concurrency's task racing pattern.
/// The macro wraps the property test body with `withPropertyTimeout`,
/// which runs the test and a timeout timer concurrently, cancelling
/// whichever completes second.
///
/// See ``TimeoutDuration`` and ``withPropertyTimeout(_:operation:)`` for more details.
@attached(peer)
public macro Timeout(seconds: Double) =
  #externalMacro(
    module: "InvariantSwiftMacros",
    type: "TimeoutMacro"
  )

/// Enforces a timeout on a property test using TimeoutDuration.
///
/// See ``Timeout(seconds:)`` for documentation and usage examples.
@attached(peer)
public macro Timeout(_ duration: TimeoutDuration) =
  #externalMacro(
    module: "InvariantSwiftMacros",
    type: "TimeoutMacro"
  )
