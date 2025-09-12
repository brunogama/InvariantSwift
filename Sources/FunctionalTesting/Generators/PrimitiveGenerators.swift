import Foundation

// MARK: - Primitive Type Generators

extension Gen where T == Int {
  /// Generate integers with edge cases and shrinking
  public static var int: Gen<Int> {
    Gen<Int>(
      generate: { rng, size in
        // Include edge cases based on size
        if size.value <= 5 {
          let edgeCases = [0, 1, -1, Int.min, Int.max]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        let range = min(size.value * 10, Int.max / 2)
        return Int.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [Int] = []

        // Shrink towards zero
        if n != 0 {
          shrunk.append(0)
        }

        // Shrink by halving (preserving sign)
        if abs(n) > 1 {
          let half = n / 2
          if half != n && half != 0 {
            shrunk.append(half)
          }
        }

        // Shrink by subtracting/adding 1
        if n > 0 {
          shrunk.append(n - 1)
        } else if n < 0 {
          shrunk.append(n + 1)
        }

        return shrunk.removingDuplicates()
      }
    )
  }

  /// Generate integers within a specific range
  public static func int(in range: ClosedRange<Int>) -> Gen<Int> {
    Gen<Int>(
      generate: { rng, _ in
        Int.random(in: range, using: &rng)
      },
      shrink: Shrink { n in
        var shrunk: [Int] = []

        // Shrink towards the lower bound
        if n > range.lowerBound {
          shrunk.append(range.lowerBound)
        }

        // Shrink by halving towards lower bound
        let distance = n - range.lowerBound
        if distance > 1 {
          let halfway = range.lowerBound + distance / 2
          if halfway != n {
            shrunk.append(halfway)
          }
        }

        // Shrink by decrementing
        if n > range.lowerBound {
          shrunk.append(n - 1)
        }

        return shrunk.removingDuplicates()
      }
    )
  }
}

extension Gen where T == Bool {
  /// Generate booleans with equal probability
  public static var bool: Gen<Bool> {
    Gen<Bool>(
      generate: { rng, _ in
        Bool.random(using: &rng)
      },
      shrink: Shrink { b in
        // Boolean shrinks to false
        b ? [false] : []
      }
    )
  }
}

extension Gen where T == Double {
  /// Generate doubles with edge cases
  public static var double: Gen<Double> {
    Gen<Double>(
      generate: { rng, size in
        // Include edge cases
        if size.value <= 5 {
          let edgeCases = [0.0, 1.0, -1.0, Double.infinity, -Double.infinity, Double.nan]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
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

        // Shrink towards zero
        if d != 0.0 {
          shrunk.append(0.0)
        }

        // Shrink by halving
        if abs(d) > 1.0 {
          let half = d / 2.0
          if half != d {
            shrunk.append(half)
          }
        }

        // Shrink to simple values
        if d > 1.0 {
          shrunk.append(1.0)
        } else if d < -1.0 {
          shrunk.append(-1.0)
        }

        return shrunk.removingDuplicates()
      }
    )
  }

  /// Generate doubles within a specific range
  public static func double(in range: ClosedRange<Double>) -> Gen<Double> {
    Gen<Double>(
      generate: { rng, _ in
        Double.random(in: range, using: &rng)
      },
      shrink: Shrink { d in
        var shrunk: [Double] = []

        // Shrink towards lower bound
        if d > range.lowerBound {
          shrunk.append(range.lowerBound)
        }

        // Shrink by halving towards lower bound
        let distance = d - range.lowerBound
        if distance > 0.001 {  // Avoid floating point precision issues
          let halfway = range.lowerBound + distance / 2.0
          if abs(halfway - d) > 0.001 {
            shrunk.append(halfway)
          }
        }

        return shrunk.removingDuplicates()
      }
    )
  }
}

// Note: Float generator is defined in NumericGenerators.swift to avoid conflicts

extension Gen where T == String {
  /// Generate strings with various lengths and character sets
  public static var string: Gen<String> {
    Gen<String>(
      generate: { rng, size in
        let length = Int.random(in: 0...size.value, using: &rng)
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "

        return String(
          (0..<length).map { _ in
            characters.randomElement(using: &rng)!
          }
        )
      },
      shrink: Shrink { s in
        var shrunk: [String] = []

        // Shrink to empty string
        if !s.isEmpty {
          shrunk.append("")
        }

        // Shrink by removing characters
        if s.count > 1 {
          // Remove first character
          shrunk.append(String(s.dropFirst()))

          // Remove last character
          shrunk.append(String(s.dropLast()))

          // Remove middle character
          let middleIndex = s.index(s.startIndex, offsetBy: s.count / 2)
          var withoutMiddle = s
          withoutMiddle.remove(at: middleIndex)
          shrunk.append(withoutMiddle)
        }

        return shrunk.removingDuplicates()
      }
    )
  }

  /// Generate ASCII strings
  public static var asciiString: Gen<String> {
    Gen<String>(
      generate: { rng, size in
        let length = Int.random(in: 0...size.value, using: &rng)
        let asciiRange: ClosedRange<UInt8> = 32...126  // Printable ASCII

        return String(
          bytes: (0..<length).map { _ in
            UInt8.random(in: asciiRange, using: &rng)
          },
          encoding: .ascii
        ) ?? ""
      },
      shrink: Gen.string.shrink  // Reuse string shrinking
    )
  }
}

extension Gen where T == UUID {
  /// Generate UUIDs
  public static var uuid: Gen<UUID> {
    Gen<UUID>(
      generate: { _, _ in UUID() },
      shrink: Shrink { _ in [] }  // UUIDs don't shrink meaningfully
    )
  }
}

// MARK: - Character Generators

extension Gen where T == Character {
  /// Generate alphabetic characters
  public static var letter: Gen<Character> {
    Gen<Character>(
      generate: { rng, _ in
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return letters.randomElement(using: &rng)!
      },
      shrink: Shrink { c in
        // Shrink towards 'a'
        if c != "a" {
          return ["a"]
        }
        return []
      }
    )
  }

  /// Generate lowercase letters
  public static var lowercase: Gen<Character> {
    Gen<Character>(
      generate: { rng, _ in
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return letters.randomElement(using: &rng)!
      },
      shrink: Shrink { c in
        if c != "a" {
          return ["a"]
        }
        return []
      }
    )
  }

  /// Generate digits
  public static var digit: Gen<Character> {
    Gen<Character>(
      generate: { rng, _ in
        let digits = "0123456789"
        return digits.randomElement(using: &rng)!
      },
      shrink: Shrink { c in
        if c != "0" {
          return ["0"]
        }
        return []
      }
    )
  }
}

// MARK: - Utility Extensions

private extension Array where Element: Hashable {
  func removingDuplicates() -> [Element] {
    Array(Set(self))
  }
}
