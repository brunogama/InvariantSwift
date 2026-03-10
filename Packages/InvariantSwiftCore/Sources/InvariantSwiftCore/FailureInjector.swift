import Foundation

// MARK: - FailureInjector

/// **First-class failure injection for model-based tests**
///
/// `FailureInjector` lets you deterministically inject errors into specific command
/// executions without modifying command implementations. It is passed to
/// ``ModelTestRunner/runModelTest(_:config:failureInjector:)`` and called just before
/// each `command.execute()`.
///
/// Factory methods:
/// - ``atIndex(_:error:)`` — fail every time a specific step index is reached
/// - ``whenCommand(_:error:)`` — fail every time a predicate matches the command
/// - ``onceAtIndex(_:error:)`` — fail exactly once at the first matching index
/// - ``never`` — no-op injector (default)
///
/// - Note: `FailureInjector` is `@unchecked Sendable`. The `onceAtIndex` factory
///   uses an `NSLock` to protect its once-only state; all other factories are pure.
///
/// - See Also: ``CommandStep``, ``CommandTrace``, ``ModelTestRunner``
public struct FailureInjector<C: Command>: @unchecked Sendable {
  /// The check closure: given a command and its zero-based step index, return an
  /// `Error` to inject, or `nil` to let execution proceed normally.
  let check: @Sendable (C, Int) -> (any Error)?

  // MARK: - Factories

  /// Injects an error every time step `index` is reached.
  public static func atIndex(_ index: Int, error: any Error = InjectedError.default) -> Self {
    Self { _, i in i == index ? error : nil }
  }

  /// Injects an error every time `predicate` returns `true` for the command.
  public static func whenCommand(
    _ predicate: @escaping @Sendable (C) -> Bool,
    error: any Error = InjectedError.default
  ) -> Self {
    Self { cmd, _ in predicate(cmd) ? error : nil }
  }

  /// Injects an error exactly once, the first time step `index` is reached.
  /// Subsequent arrivals at the same index succeed normally.
  ///
  /// Thread-safety is guaranteed by `_OnceInjectorState`, an `@unchecked Sendable`
  /// reference type that wraps the `fired` flag behind an `NSLock`.
  public static func onceAtIndex(_ index: Int, error: any Error = InjectedError.default) -> Self {
    let state = _OnceInjectorState()
    return Self { _, i in
      guard i == index else { return nil }
      return state.tryFire() ? error : nil
    }
  }

  /// No-op injector — never injects a failure.
  public static var never: Self {
    Self { _, _ in nil }
  }
}

// MARK: - _OnceInjectorState

/// Internal lock-protected state for the `onceAtIndex` factory.
///
/// Must be a reference type so it can be captured by a `@Sendable` closure
/// without triggering Swift 6 concurrency errors on mutable-variable capture.
final class _OnceInjectorState: @unchecked Sendable {
  private let lock = NSLock()
  private var fired = false

  /// Marks the state as fired and returns `true` the first time; `false` thereafter.
  func tryFire() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard !fired else { return false }
    fired = true
    return true
  }
}

// MARK: - InjectedError

/// Default error produced by ``FailureInjector`` factories.
public enum InjectedError: Error, CustomStringConvertible {
  /// Generic injected failure used when no custom error is provided.
  case `default`
  /// Custom injected failure carrying a human-readable message.
  case message(String)

  public var description: String {
    switch self {
    case .default: return "injected failure"
    case .message(let msg): return "injected failure: \(msg)"
    }
  }
}
