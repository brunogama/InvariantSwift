import Foundation

/// Builder pattern for constructing configuration instances using key paths
///
/// ConfigBuilder provides a fluent API for incremental configuration construction
/// with method chaining, leveraging Swift's KeyPath system for type-safe field updates.
///
/// **Usage:**
/// ```swift
/// let config = ConfigBuilder<PropertyConfig>
///   .from(.default)
///   .set(\.iterations, to: 300)
///   .set(\.maxShrinks, to: 50)
///   .update(\.maxDiscarded) { $0 / 2 }
///   .build()
/// ```
///
/// **Design:**
/// - Generic over configuration type `T`
/// - Uses WritableKeyPath for type-safe field access
/// - Immutable updates via struct copying
/// - Method chaining for ergonomic API
///
/// - Note: ConfigBuilder is designed for test configuration scenarios where
///   fluent APIs improve readability over manual struct construction.
public struct ConfigBuilder<T> {
  private var config: T

  /// Start building from an existing configuration instance
  ///
  /// - Parameter initial: The starting configuration to build upon
  /// - Returns: A new ConfigBuilder wrapping the initial configuration
  ///
  /// **Example:**
  /// ```swift
  /// ConfigBuilder<PropertyConfig>.from(.default)
  /// ```
  public static func from(_ initial: T) -> Self {
    Self(config: initial)
  }

  /// Set a field to a specific value using a key path
  ///
  /// - Parameters:
  ///   - keyPath: Writable key path to the field to update
  ///   - value: New value for the field
  /// - Returns: New ConfigBuilder with updated configuration
  ///
  /// **Example:**
  /// ```swift
  /// builder.set(\.iterations, to: 200)
  /// ```
  public func set<Value>(
    _ keyPath: WritableKeyPath<T, Value>,
    to value: Value
  ) -> Self {
    var updated = config
    updated[keyPath: keyPath] = value
    return Self(config: updated)
  }

  /// Update a field by transforming its current value using a key path
  ///
  /// - Parameters:
  ///   - keyPath: Writable key path to the field to update
  ///   - transform: Function to transform the current value
  /// - Returns: New ConfigBuilder with updated configuration
  ///
  /// **Example:**
  /// ```swift
  /// builder.update(\.maxDiscarded) { $0 / 2 }
  /// ```
  public func update<Value>(
    _ keyPath: WritableKeyPath<T, Value>,
    _ transform: (Value) -> Value
  ) -> Self {
    var updated = config
    let currentValue = updated[keyPath: keyPath]
    updated[keyPath: keyPath] = transform(currentValue)
    return Self(config: updated)
  }

  /// Extract the final configuration instance
  ///
  /// - Returns: The built configuration instance
  ///
  /// **Example:**
  /// ```swift
  /// let config = builder.build()
  /// ```
  public func build() -> T {
    config
  }
}
