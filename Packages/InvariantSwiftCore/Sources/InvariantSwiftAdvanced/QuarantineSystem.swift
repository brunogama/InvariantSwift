import InvariantSwiftCore
import Foundation

// MARK: - Quarantine System
//
// Quarantine-related types, builders, and string pool utilities for FlakeHunter.
// Extracted from FlakeHunter.swift to keep the actor file under budget.

// MARK: - String Pool

/// **String pool for efficient string interning**
///
/// Provides memory-efficient storage of frequently-used strings.
/// Identical strings share storage, reducing memory allocations.
///
/// **Memory Optimization Benefits:**
/// - Deduplication of repeated test IDs and reason strings
/// - Reduced memory churn from temporary string allocations
/// - Actor isolation for thread-safe access
public actor StringPool {
  private var pool: Set<String> = []

  /// Shared instance for global string pooling
  public static let shared = StringPool()

  /// Initialize a new string pool
  public init() {}

  /// Intern a string, returning the canonical instance
  ///
  /// - Parameter string: String to intern
  /// - Returns: Canonical string instance from the pool
  public func intern(_ string: String) -> String {
    if let existing = pool.first(where: { $0 == string }) {
      return existing
    }
    pool.insert(string)
    return string
  }

  /// Intern multiple strings
  ///
  /// - Parameter strings: Strings to intern
  /// - Returns: Array of canonical string instances
  public func internAll(_ strings: [String]) -> [String] {
    strings.map { intern($0) }
  }

  /// Number of unique strings in the pool
  public var count: Int { pool.count }

  /// Clear all interned strings
  public func clear() {
    pool.removeAll()
  }

  /// Fire-and-forget interning from synchronous contexts
  nonisolated public func internAsync(_ string: String) {
    Task { _ = await self.intern(string) }
  }
}

// MARK: - Quarantine Reason Builder

/// **Efficient quarantine reason builder**
///
/// Provides zero-copy string building for quarantine reasons,
/// reducing temporary allocations during reason message construction.
///
/// **Memory Optimization Benefits:**
/// - Pre-allocated buffer for common reason patterns
/// - Reusable across multiple quarantine operations
/// - Eliminates intermediate string concatenations
public struct QuarantineReasonBuilder: Sendable {
  private var components: [String] = []

  /// Creates a new reason builder
  public init() {}

  /// Add a component to the reason
  ///
  /// - Parameter component: Text component to add
  /// - Returns: Self for chaining
  @discardableResult
  public mutating func add(_ component: String) -> Self {
    components.append(component)
    return self
  }

  /// Add flakiness score component
  @discardableResult
  public mutating func withFlakinessScore(_ score: Double) -> Self {
    components.append("flakiness score \(String(format: "%.2f", score))")
    return self
  }

  /// Add confidence component
  @discardableResult
  public mutating func withConfidence(_ confidence: Double) -> Self {
    components.append("confidence \(String(format: "%.2f", confidence))")
    return self
  }

  /// Add rehabilitation attempt count
  @discardableResult
  public mutating func withRehabilitationAttempts(_ count: Int) -> Self {
    if count > 0 {
      components.append("after \(count) failed rehabilitation attempts")
    }
    return self
  }

  /// Build the final reason string
  ///
  /// - Parameter prefix: Optional prefix for the reason
  /// - Returns: Complete reason string
  public func build(prefix: String = "Automatic quarantine:") -> String {
    guard !components.isEmpty else { return prefix }
    return "\(prefix) \(components.joined(separator: ", "))"
  }

  /// Reset the builder for reuse
  public mutating func reset() {
    components.removeAll(keepingCapacity: true)
  }
}
