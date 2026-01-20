import Foundation
import InvariantSwiftCore

/// Lens extensions for Seed type
///
/// Provides functional lens-based access to Seed properties, enabling
/// immutable updates and composition with other lenses.
extension Seed {
  /// Lens for accessing and modifying the seed value
  ///
  /// **Get:** Extracts the raw UInt64 value from the Seed
  /// **Set:** Creates a new Seed with the specified value
  ///
  /// - Example:
  ///   ```swift
  ///   let seed = Seed(value: 100)
  ///   let val = Seed.seedValue.get(seed)     // 100
  ///   let newSeed = Seed.seedValue.set(200, seed)  // Seed(value: 200)
  ///   ```
  public static var seedValue: Lens<Seed, UInt64> {
    Lens(
      get: { $0.rawValue },
      set: { newValue, _ in Seed(value: newValue) }
    )
  }

  /// Utility function for incrementing Seed by a delta
  ///
  /// Returns a function that increments a Seed by the given delta using
  /// wrapping arithmetic (safe for all delta values).
  ///
  /// - Parameter delta: Signed integer delta to add to the seed
  /// - Returns: Function that transforms Seed by incrementing
  ///
  /// - Example:
  ///   ```swift
  ///   let seed = Seed(value: 100)
  ///   let incremented = Seed.increment(by: 50)(seed)  // Seed(value: 150)
  ///   let decremented = Seed.increment(by: -30)(seed)  // Seed(value: 70)
  ///   ```
  public static func increment(by delta: Int) -> (Seed) -> Seed {
    { seed in
      let newValue = seed.rawValue &+ UInt64(bitPattern: Int64(delta))
      return Seed(value: newValue)
    }
  }
}
