import Foundation
import InvariantSwiftCore

/// Lens extensions for Size type
///
/// Provides functional lens-based access to Size properties, enabling
/// immutable updates and composition with other lenses.
///
/// - Note: The lens property is named `valueLens` instead of `value` to avoid
///   Swift's limitation with static/instance property name collision.
extension Size {
  /// Lens for accessing and modifying the underlying size value
  ///
  /// **Get:** Extracts the numeric value from the Size
  /// **Set:** Creates a new Size with the specified value
  ///
  /// - Example:
  ///   ```swift
  ///   let size = Size(value: 10)
  ///   let val = Size.valueLens.get(size)     // 10
  ///   let newSize = Size.valueLens.set(20, size)  // Size(value: 20)
  ///   ```
  public static var valueLens: Lens<Size, Int> {
    Lens(
      get: { $0.value },
      set: { newValue, _ in Size(value: newValue) }
    )
  }

  /// Utility function for scaling Size by a multiplicative factor
  ///
  /// Returns a function that scales a Size by the given factor.
  /// Useful for compositional size manipulation in lens chains.
  ///
  /// - Parameter factor: Multiplicative factor (e.g., 2.0 for double, 0.5 for half)
  /// - Returns: Function that transforms Size by scaling
  ///
  /// - Example:
  ///   ```swift
  ///   let size = Size(value: 10)
  ///   let scaled = Size.scale(by: 2.0)(size)  // Size(value: 20)
  ///   ```
  public static func scale(by factor: Double) -> (Size) -> Size {
    { size in size.scaled(by: factor) }
  }

  /// Utility function for clamping Size to a range
  ///
  /// Returns a function that clamps a Size value to the specified range.
  /// Useful for enforcing size bounds in generator pipelines.
  ///
  /// - Parameter range: Closed range to clamp values to
  /// - Returns: Function that transforms Size by clamping
  ///
  /// - Example:
  ///   ```swift
  ///   let size = Size(value: 10)
  ///   let clamped = Size.clamp(to: 1...5)(size)  // Size(value: 5)
  ///   ```
  public static func clamp(to range: ClosedRange<Int>) -> (Size) -> Size {
    { size in
      let clamped = min(max(size.value, range.lowerBound), range.upperBound)
      return Size(value: clamped)
    }
  }
}
