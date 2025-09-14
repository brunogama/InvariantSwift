import Foundation
import CoreGraphics

// MARK: - Integer Type Generators

extension Gen where T == Int8 {
  /// Generate Int8 with comprehensive edge cases
  public static var int8: Gen<Int8> {
    Gen<Int8>(
      generate: { rng, size in
        // Edge cases
        if size.value <= 5 {
          let edgeCases: [Int8] = [0, 1, -1, Int8.min, Int8.max, 127, -128]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(Int8(size.value), Int8.max / 2)
        return Int8.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [Int8] = []

        if n != 0 { shrunk.append(0) }
        if abs(n) > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) } else if n < 0 { shrunk.append(n + 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == Int16 {
  /// Generate Int16 with comprehensive edge cases
  public static var int16: Gen<Int16> {
    Gen<Int16>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [Int16] = [0, 1, -1, Int16.min, Int16.max, 32767, -32768]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(Int16(size.value * 100), Int16.max / 2)
        return Int16.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [Int16] = []

        if n != 0 { shrunk.append(0) }
        if abs(n) > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) } else if n < 0 { shrunk.append(n + 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == Int32 {
  /// Generate Int32 with comprehensive edge cases
  public static var int32: Gen<Int32> {
    Gen<Int32>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [Int32] = [0, 1, -1, Int32.min, Int32.max]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(Int32(size.value * 1000), Int32.max / 2)
        return Int32.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [Int32] = []

        if n != 0 { shrunk.append(0) }
        if abs(n) > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) } else if n < 0 { shrunk.append(n + 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == Int64 {
  /// Generate Int64 with comprehensive edge cases
  public static var int64: Gen<Int64> {
    Gen<Int64>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [Int64] = [0, 1, -1, Int64.min, Int64.max]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(Int64(size.value * 10000), Int64.max / 2)
        return Int64.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [Int64] = []

        if n != 0 { shrunk.append(0) }
        if abs(n) > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) } else if n < 0 { shrunk.append(n + 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

// MARK: - Unsigned Integer Generators

extension Gen where T == UInt {
  /// Generate UInt with comprehensive edge cases
  public static var uint: Gen<UInt> {
    Gen<UInt>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [UInt] = [0, 1, UInt.max, UInt.max - 1]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(UInt(size.value * 10), UInt.max / 2)
        return UInt.random(in: 0...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [UInt] = []

        if n != 0 { shrunk.append(0) }
        if n > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == UInt8 {
  /// Generate UInt8 with comprehensive edge cases
  public static var uint8: Gen<UInt8> {
    Gen<UInt8>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [UInt8] = [0, 1, UInt8.max, 255]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(UInt8(size.value), UInt8.max / 2)
        return UInt8.random(in: 0...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [UInt8] = []

        if n != 0 { shrunk.append(0) }
        if n > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == UInt16 {
  /// Generate UInt16 with comprehensive edge cases
  public static var uint16: Gen<UInt16> {
    Gen<UInt16>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [UInt16] = [0, 1, UInt16.max, 65535]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(UInt16(size.value * 100), UInt16.max / 2)
        return UInt16.random(in: 0...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [UInt16] = []

        if n != 0 { shrunk.append(0) }
        if n > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == UInt32 {
  /// Generate UInt32 with comprehensive edge cases
  public static var uint32: Gen<UInt32> {
    Gen<UInt32>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [UInt32] = [0, 1, UInt32.max]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(UInt32(size.value * 1000), UInt32.max / 2)
        return UInt32.random(in: 0...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [UInt32] = []

        if n != 0 { shrunk.append(0) }
        if n > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == UInt64 {
  /// Generate UInt64 with comprehensive edge cases
  public static var uint64: Gen<UInt64> {
    Gen<UInt64>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [UInt64] = [0, 1, UInt64.max]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(UInt64(size.value * 10000), UInt64.max / 2)
        return UInt64.random(in: 0...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [UInt64] = []

        if n != 0 { shrunk.append(0) }
        if n > 1 {
          let half = n / 2
          if half != n && half != 0 { shrunk.append(half) }
        }
        if n > 0 { shrunk.append(n - 1) }

        return Array(Set(shrunk))
      }
    )
  }
}

// MARK: - Floating Point Generators

extension Gen where T == Float {
  /// Generate Float with comprehensive edge cases including NaN and infinity
  public static var float: Gen<Float> {
    Gen<Float>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [Float] = [
            0.0, 1.0, -1.0, Float.infinity, -Float.infinity, Float.nan,
            Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude,
            Float.leastNormalMagnitude, -Float.leastNormalMagnitude,
            Float.leastNonzeroMagnitude, -Float.leastNonzeroMagnitude,
            Float.pi, -Float.pi, Float.ulpOfOne,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = Float(size.value)
        return Float.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { f in
        var shrunk: [Float] = []

        // Handle special values
        if f.isInfinite || f.isNaN {
          return [0.0, 1.0, -1.0]
        }

        if f != 0.0 { shrunk.append(0.0) }

        if abs(f) > 1.0 {
          let half = f / 2.0
          if half != f { shrunk.append(half) }
        }

        if f > 1.0 { shrunk.append(1.0) } else if f < -1.0 { shrunk.append(-1.0) }

        return Array(Set(shrunk))
      }
    )
  }
}

extension Gen where T == Double {
  /// Enhanced Double generator with more comprehensive edge cases
  public static var enhancedDouble: Gen<Double> {
    Gen<Double>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [Double] = [
            0.0, 1.0, -1.0, Double.infinity, -Double.infinity, Double.nan,
            Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude,
            Double.leastNormalMagnitude, -Double.leastNormalMagnitude,
            Double.leastNonzeroMagnitude, -Double.leastNonzeroMagnitude,
            Double.pi, -Double.pi, Double.ulpOfOne, 2.0 * Double.pi,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = Double(size.value)
        return Double.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { d in
        var shrunk: [Double] = []

        // Handle special values
        if d.isInfinite || d.isNaN {
          return [0.0, 1.0, -1.0]
        }

        if d != 0.0 { shrunk.append(0.0) }

        if abs(d) > 1.0 {
          let half = d / 2.0
          if half != d { shrunk.append(half) }
        }

        if d > 1.0 { shrunk.append(1.0) } else if d < -1.0 { shrunk.append(-1.0) }

        return Array(Set(shrunk))
      }
    )
  }
}

#if !os(watchOS)  // Float16 is not available on watchOS
extension Gen where T == Float16 {
  /// Generate Float16 with comprehensive edge cases
  public static var float16: Gen<Float16> {
    Gen<Float16>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [Float16] = [
            0.0, 1.0, -1.0, Float16.infinity, -Float16.infinity, Float16.nan,
            Float16.greatestFiniteMagnitude, -Float16.greatestFiniteMagnitude,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = Float16(min(size.value, 100))  // Float16 has limited range
        return Float16.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { f in
        var shrunk: [Float16] = []

        if f.isInfinite || f.isNaN {
          return [0.0, 1.0, -1.0]
        }

        if f != 0.0 { shrunk.append(0.0) }

        if abs(f) > 1.0 {
          let half = f / 2.0
          if half != f { shrunk.append(half) }
        }

        if f > 1.0 { shrunk.append(1.0) } else if f < -1.0 { shrunk.append(-1.0) }

        return Array(Set(shrunk))
      }
    )
  }
}
#endif

extension Gen where T == CGFloat {
  /// Generate CGFloat with comprehensive edge cases
  public static var cgFloat: Gen<CGFloat> {
    Gen<CGFloat>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [CGFloat] = [
            0.0, 1.0, -1.0, CGFloat.infinity, -CGFloat.infinity, CGFloat.nan,
            CGFloat.greatestFiniteMagnitude, -CGFloat.greatestFiniteMagnitude,
            CGFloat.leastNormalMagnitude, -CGFloat.leastNormalMagnitude,
            CGFloat.pi, -CGFloat.pi,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = CGFloat(size.value)
        return CGFloat.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { f in
        var shrunk: [CGFloat] = []

        if f.isInfinite || f.isNaN {
          return [0.0, 1.0, -1.0]
        }

        if f != 0.0 { shrunk.append(0.0) }

        if abs(f) > 1.0 {
          let half = f / 2.0
          if half != f { shrunk.append(half) }
        }

        if f > 1.0 { shrunk.append(1.0) } else if f < -1.0 { shrunk.append(-1.0) }

        return Array(Set(shrunk))
      }
    )
  }
}

// MARK: - Decimal Generators

extension Gen where T == Decimal {
  /// Generate Decimal with comprehensive edge cases
  public static var decimal: Gen<Decimal> {
    Gen<Decimal>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [Decimal] = [
            0, 1, -1, Decimal.greatestFiniteMagnitude, -Decimal.greatestFiniteMagnitude,
            Decimal.leastNormalMagnitude, -Decimal.leastNormalMagnitude,
            Decimal.nan, Decimal.quietNaN,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        // Create decimal from components
        let isNegative = Bool.random(using: &rng)
        let exponent = Int8.random(in: -128...127, using: &rng)
        let length = UInt32.random(in: 1...8, using: &rng)  // Max 8 significand parts

        var mantissa: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) = (
          0, 0, 0, 0, 0, 0, 0, 0
        )

        // Generate random mantissa components
        withUnsafeMutableBytes(of: &mantissa) { buffer in
          let uint16Buffer = buffer.bindMemory(to: UInt16.self)
          for i in 0..<Int(length) {
            uint16Buffer[i] = UInt16.random(in: 0...UInt16.max, using: &rng)
          }
        }

        return Decimal(
          _exponent: Int32(exponent),
          _length: length,
          _isNegative: isNegative ? 1 : 0,
          _isCompact: 1,
          _reserved: 0,
          _mantissa: mantissa
        )
      },
      shrink: Shrink { decimal in
        var shrunk: [Decimal] = []

        if decimal.isNaN {
          return [0, 1, -1]
        }

        if decimal != 0 { shrunk.append(0) }

        if abs(decimal) > 1 {
          let half = decimal / 2
          if half != decimal { shrunk.append(half) }
        }

        if decimal > 1 { shrunk.append(1) } else if decimal < -1 { shrunk.append(-1) }

        return Array(Set(shrunk))
      }
    )
  }
}

// MARK: - Numeric Protocol Conforming Generators

extension Gen {
  /// Generate any numeric type that conforms to BinaryInteger
  public static func binaryInteger<U: BinaryInteger>() -> Gen<U> where U: Sendable {
    Gen<U>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [U] = [U(0), U(1), U(-1)].compactMap { $0 }
          if Bool.random(using: &rng) && !edgeCases.isEmpty {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = min(size.value, 1000)
        let value = Int.random(in: -range...range, using: &rng)
        return U(value)
      },
      shrink: Shrink { n in
        var shrunk: [U] = []

        let zero = U(0)
        if n != zero { shrunk.append(zero) }

        // Try to shrink by halving
        if let two = U(exactly: 2), n > U(1) || n < U(-1) {
          let half = n / two
          if half != n && half != zero {
            shrunk.append(half)
          }
        }

        return Array(Set(shrunk))  // Use Set directly since BinaryInteger is Hashable
      }
    )
  }

  /// Generate any floating point type that conforms to BinaryFloatingPoint
  public static func binaryFloatingPoint<U: BinaryFloatingPoint>() -> Gen<U>
  where U: Sendable, U.RawSignificand: FixedWidthInteger {
    Gen<U>(
      generate: { rng, size in
        if size.value <= 5 {
          let edgeCases: [U] = [U(0), U(1), U(-1), U.infinity, -U.infinity, U.nan]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng) ?? 0
          }
        }

        let range = U(size.value)
        return U.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { f in
        var shrunk: [U] = []

        if f.isInfinite || f.isNaN {
          return [U(0), U(1), U(-1)]
        }

        let zero = U(0)
        if f != zero { shrunk.append(zero) }

        let one = U(1)
        let minusOne = U(-1)

        if abs(f) > one {
          let half = f / U(2)
          if half != f { shrunk.append(half) }
        }

        if f > one { shrunk.append(one) } else if f < minusOne { shrunk.append(minusOne) }

        return Array(Set(shrunk))  // Use Set directly for deduplication
      }
    )
  }
}
