import Foundation
import InvariantSwiftCore

// MARK: - Generatable Conformances for Primitive Types

/// This file provides `Generatable` conformances for Swift standard library primitive types.
///
/// These conformances bridge the `.arbitrary` static property to the corresponding `Gen<T>`
/// generators defined in `PrimitiveGenerators.swift` and `NumericGenerators.swift`.
///
/// This enables generated test code (e.g., from Ghostwriter) to use the ergonomic
/// `String.arbitrary` syntax instead of the more verbose `Gen<String>.string` pattern.
///
/// - Example:
///   ```swift
///   // Generated test code can now use:
///   let gen = String.arbitrary  // → Gen<String>.string
///
///   // Instead of:
///   let gen = Gen<String>.string
///   ```

// MARK: - Integer Types

extension Int: Generatable {
  /// Generator for arbitrary Int values with comprehensive edge cases and shrinking.
  ///
  /// Bridges to `Gen<Int>.int` which produces values across the full Int range
  /// with built-in edge case handling (0, ±1, Int.min, Int.max) and shrinking toward zero.
  ///
  /// - See Also: ``Gen/int``
  public static var arbitrary: Gen<Int> { Gen<Int>.int }
}

extension Int8: Generatable {
  /// Generator for arbitrary Int8 values with edge cases.
  ///
  /// Bridges to `Gen<Int8>.int8` which produces values in the Int8 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/int8``
  public static var arbitrary: Gen<Int8> { Gen<Int8>.int8 }
}

extension Int16: Generatable {
  /// Generator for arbitrary Int16 values with edge cases.
  ///
  /// Bridges to `Gen<Int16>.int16` which produces values in the Int16 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/int16``
  public static var arbitrary: Gen<Int16> { Gen<Int16>.int16 }
}

extension Int32: Generatable {
  /// Generator for arbitrary Int32 values with edge cases.
  ///
  /// Bridges to `Gen<Int32>.int32` which produces values in the Int32 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/int32``
  public static var arbitrary: Gen<Int32> { Gen<Int32>.int32 }
}

extension Int64: Generatable {
  /// Generator for arbitrary Int64 values with edge cases.
  ///
  /// Bridges to `Gen<Int64>.int64` which produces values in the Int64 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/int64``
  public static var arbitrary: Gen<Int64> { Gen<Int64>.int64 }
}

// MARK: - Unsigned Integer Types

extension UInt: Generatable {
  /// Generator for arbitrary UInt values with edge cases.
  ///
  /// Bridges to `Gen<UInt>.uint` which produces values in the UInt range
  /// with edge case handling (0, 1, UInt.max) and shrinking toward zero.
  ///
  /// - See Also: ``Gen/uint``
  public static var arbitrary: Gen<UInt> { Gen<UInt>.uint }
}

extension UInt8: Generatable {
  /// Generator for arbitrary UInt8 values with edge cases.
  ///
  /// Bridges to `Gen<UInt8>.uint8` which produces values in the UInt8 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/uint8``
  public static var arbitrary: Gen<UInt8> { Gen<UInt8>.uint8 }
}

extension UInt16: Generatable {
  /// Generator for arbitrary UInt16 values with edge cases.
  ///
  /// Bridges to `Gen<UInt16>.uint16` which produces values in the UInt16 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/uint16``
  public static var arbitrary: Gen<UInt16> { Gen<UInt16>.uint16 }
}

extension UInt32: Generatable {
  /// Generator for arbitrary UInt32 values with edge cases.
  ///
  /// Bridges to `Gen<UInt32>.uint32` which produces values in the UInt32 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/uint32``
  public static var arbitrary: Gen<UInt32> { Gen<UInt32>.uint32 }
}

extension UInt64: Generatable {
  /// Generator for arbitrary UInt64 values with edge cases.
  ///
  /// Bridges to `Gen<UInt64>.uint64` which produces values in the UInt64 range
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/uint64``
  public static var arbitrary: Gen<UInt64> { Gen<UInt64>.uint64 }
}

// MARK: - Floating Point Types

extension Double: Generatable {
  /// Generator for arbitrary Double values (finite only by default).
  ///
  /// Bridges to `Gen<Double>.double` which produces finite Double values
  /// with edge case handling (0.0, ±1.0) and shrinking toward zero.
  ///
  /// - Note: For NaN/infinity values, use `Gen<Double>.double(mode: .allowNaN)`
  ///
  /// - See Also: ``Gen/double``, ``Gen/double(mode:)``
  public static var arbitrary: Gen<Double> { Gen<Double>.double }
}

extension Float: Generatable {
  /// Generator for arbitrary Float values (finite only by default).
  ///
  /// Bridges to `Gen<Float>.float` which produces finite Float values
  /// with edge case handling and shrinking toward zero.
  ///
  /// - See Also: ``Gen/float``
  public static var arbitrary: Gen<Float> { Gen<Float>.float }
}

// MARK: - Boolean Type

extension Bool: Generatable {
  /// Generator for arbitrary Boolean values with equal probability.
  ///
  /// Bridges to `Gen<Bool>.bool` which produces true/false with 50/50 distribution
  /// and shrinks true → false.
  ///
  /// - See Also: ``Gen/bool``
  public static var arbitrary: Gen<Bool> { Gen<Bool>.bool }
}

// MARK: - String Type

extension String: Generatable {
  /// Generator for arbitrary String values.
  ///
  /// Bridges to `Gen<String>.string` which produces Unicode strings with
  /// variable length determined by the size parameter and shrinking toward empty string.
  ///
  /// - See Also: ``Gen/string``, ``Gen/asciiString``
  public static var arbitrary: Gen<String> { Gen<String>.string }
}

// MARK: - Character Type

extension Character: Generatable {
  /// Generator for arbitrary Character values (letters).
  ///
  /// Bridges to `Gen<Character>.letter` which produces random letters from a-zA-Z
  /// with shrinking toward 'a'.
  ///
  /// - See Also: ``Gen/letter``, ``Gen/lowercase``, ``Gen/digit``
  public static var arbitrary: Gen<Character> { Gen<Character>.letter }
}

// MARK: - UUID Type

extension UUID: Generatable {
  /// Generator for arbitrary UUID values.
  ///
  /// Bridges to `Gen<UUID>.uuid` which produces random version 4 UUIDs.
  /// UUIDs do not shrink meaningfully as they are identifiers without ordering.
  ///
  /// - See Also: ``Gen/uuid``
  public static var arbitrary: Gen<UUID> { Gen<UUID>.uuid }
}
