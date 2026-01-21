import Foundation

// MARK: - Primitive Type Generators

extension Gen where T == Int {
  /// Generate integers across the full Int range with comprehensive edge cases.
  ///
  /// This generator produces random integers from the full Int range (-2^63 to 2^63-1 on 64-bit systems)
  /// with built-in shrinking support. The generator includes special handling for edge cases like zero,
  /// Int.min, and Int.max to ensure thorough coverage of boundary conditions.
  ///
  /// **Generation Strategy:**
  /// - For small sizes (≤ 5): Biases toward edge cases (0, 1, -1, Int.min, Int.max)
  /// - For larger sizes: Generates random values in bounded ranges to prevent overflow
  /// - Edge cases are included probabilistically (50% chance when size ≤ 5)
  ///
  /// **Shrinking Strategy:**
  /// The shrinking sequence prioritizes simplification toward zero:
  /// 1. Shrinks to 0 first (simplest integer)
  /// 2. Shrinks by binary division (n/2) while preserving sign
  /// 3. Shrinks by decrementing toward zero
  ///
  /// **Mathematical Properties:**
  /// - **Identity**: Shrinking terminates at 0 for all integers
  /// - **Commutativity**: Shrinking paths converge (multiple paths may reach same value)
  /// - **Distribution**: Uniform across bounded range, edge cases biased
  ///
  /// - Returns: Generator producing Int values with built-in shrinking
  ///
  /// - Note: Size parameter affects range bounds. Default range grows with size up to ±(Int.max/2)
  ///   to prevent overflow during generation.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int>.int
  ///   let property = Property(generator: gen) { value in
  ///       #expect(value >= Int.min && value <= Int.max)
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.int(in:)``, ``Gen.positive``, ``Gen.negative``
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

        // Safely calculate range, preventing overflow
        let limit = Int.max / 2
        let range = size.value > limit / 10 ? limit : size.value * 10
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

  /// Generate integers within a specific closed range with boundary-aware shrinking.
  ///
  /// Produces random integers constrained to a closed range [lower...upper], with intelligent
  /// shrinking that respects the bounds. This is the primary way to generate bounded integers.
  ///
  /// **Generation Strategy:**
  /// - Uniform random distribution within the specified range
  /// - Size parameter is ignored (range determines bounds)
  /// - All values guaranteed to satisfy: lower ≤ value ≤ upper
  ///
  /// **Shrinking Strategy:**
  /// Shrinks toward the lower bound of the range:
  /// 1. Shrinks directly to lower bound if possible
  /// 2. Shrinks by binary division toward lower bound
  /// 3. Shrinks by decrementing toward lower bound
  ///
  /// **Edge Cases:**
  /// - Empty ranges will compile but generate invalid results (use with care)
  /// - Single-element ranges return that element every time
  /// - Large ranges (> 1 billion) will have reasonable performance
  ///
  /// - Parameters:
  ///   - range: Closed range defining lower and upper bounds (inclusive)
  ///
  /// - Returns: Generator producing integers within the specified range
  ///
  /// - Precondition: range.lowerBound ≤ range.upperBound
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int>.int(in: 1...100)
  ///   let property = Property(generator: gen) { value in
  ///       #expect(value >= 1 && value <= 100)
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.int``, ``Gen.positive``, ``Gen.negative``, ``Gen.percentage``, ``Gen.port``
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
  /// Generate Boolean values with equal probability (50% true, 50% false).
  ///
  /// Produces random Boolean values with uniform distribution. Size parameter is ignored.
  /// This is the primary way to generate arbitrary Boolean test cases.
  ///
  /// **Generation Strategy:**
  /// - Uniform 50/50 distribution between true and false
  /// - Size parameter does not affect generation
  /// - Deterministic given a seed for reproducibility
  ///
  /// **Shrinking Strategy:**
  /// - false is considered simpler than true
  /// - true shrinks to false
  /// - false shrinks to empty sequence (already minimal)
  ///
  /// **Use Cases:**
  /// - Flag testing and conditional logic
  /// - Optional feature switches
  /// - Boolean invariant verification
  /// - Exhaustive coverage of conditional branches
  ///
  /// - Returns: Generator producing Bool values (true or false)
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Bool>.bool
  ///   let property = Property(generator: gen) { flag in
  ///       // Property should hold for both true and false
  ///       #expect(testLogic(flag))
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.int(in:)``, ``Gen.element(of:)``
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
  /// Generate Double floating-point values (finite only by default).
  ///
  /// Produces random Double values with deterministic shrinking toward zero.
  /// By default, generates only finite values to ensure predictable behavior.
  ///
  /// **Generation Strategy (GEN-FLOAT-001):**
  /// - Default mode: `finiteOnly` - no NaN, no infinity (safest)
  /// - For small sizes (≤ 5): Biases toward edge cases (0.0, 1.0, -1.0)
  /// - For larger sizes: Generates values in range [-size...size]
  ///
  /// **Shrinking Strategy (SHRINK-FLOAT-001):**
  /// Deterministic convergence toward 0.0:
  /// 1. Shrinks to 0.0 (simplest value)
  /// 2. Shrinks by binary division (d/2)
  /// 3. Shrinks to ±1.0 for values outside [-1, 1]
  ///
  /// **Special Value Handling:**
  /// - Use `double(mode: .allowInfinity)` for ±infinity
  /// - Use `double(mode: .allowNaN)` for all IEEE 754 values
  /// - See ``FloatingPointMode`` for details
  ///
  /// **Cross-Platform Determinism:**
  /// - Same seed/size produces same sequence on all platforms
  /// - Follows IEEE 754 exactly for portable results
  ///
  /// - Returns: Generator producing finite Double values with deterministic shrinking
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Double>.double
  ///   let property = Property(generator: gen) { value in
  ///       #expect(value.isFinite)
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.double(in:)``, ``Gen.double(mode:)``, ``FloatingPointMode``
  public static var double: Gen<Double> {
    double(mode: .finiteOnly)
  }

  /// Generate Double floating-point values with explicit special value handling.
  ///
  /// - Parameters:
  ///   - mode: Controls whether to generate NaN/infinity
  ///
  /// - Returns: Generator producing Double values according to the specified mode
  ///
  /// - Example:
  ///   ```swift
  ///   let finiteGen = Gen<Double>.double(mode: .finiteOnly)
  ///   let withInf = Gen<Double>.double(mode: .allowInfinity)
  ///   let withNaN = Gen<Double>.double(mode: .allowNaN)
  ///   ```
  // swiftlint:disable:next cyclomatic_complexity
  public static func double(mode: FloatingPointMode) -> Gen<Double> {
    Gen<Double>(
      generate: { rng, size in
        if size.value <= 5 {
          var edgeCases = [0.0, 1.0, -1.0]

          switch mode {
          case .finiteOnly:
            break

          case .allowInfinity:
            edgeCases.append(contentsOf: [Double.infinity, -Double.infinity])

          case .allowNaN:
            edgeCases.append(contentsOf: [Double.infinity, -Double.infinity, Double.nan])
          }

          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        let range = Double(size.value)
        return Double.random(in: -range...range, using: &rng)
      },
      shrink: Shrink { d in
        var shrunk: [Double] = []

        if d.isInfinite || d.isNaN {
          return [0.0, 1.0, -1.0]
        }

        if d != 0.0 {
          shrunk.append(0.0)
        }

        if abs(d) > 1.0 {
          let half = d / 2.0
          if half != d {
            shrunk.append(half)
          }
        }

        if d > 1.0 {
          shrunk.append(1.0)
        } else if d < -1.0 {
          shrunk.append(-1.0)
        }

        return shrunk.removingDuplicates()
      }
    )
  }

  /// Generate Double values within a specific closed range with tolerance-aware shrinking.
  ///
  /// Produces random Double values constrained to a closed range, essential for numeric properties
  /// with bounded constraints. Shrinking respects bounds and floating-point precision.
  ///
  /// **Generation Strategy:**
  /// - Uniform random distribution within [lower...upper]
  /// - Size parameter is ignored (range determines bounds)
  /// - All values guaranteed to satisfy: lower ≤ value ≤ upper
  ///
  /// **Shrinking Strategy:**
  /// Shrinks toward lower bound while respecting floating-point precision:
  /// 1. Shrinks to lower bound directly
  /// 2. Shrinks by binary division toward lower bound
  /// 3. Uses 0.001 tolerance for precision-safe comparisons
  ///
  /// **Floating-Point Considerations:**
  /// - Uses 0.001 tolerance threshold to avoid precision issues
  /// - May not reach exact bounds due to floating-point representation
  /// - Subnormal numbers (very close to zero) handled safely
  ///
  /// - Parameters:
  ///   - range: Closed range defining lower and upper bounds (inclusive)
  ///
  /// - Returns: Generator producing Double values within the specified range
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Double>.double(in: 0.0...100.0)
  ///   let property = Property(generator: gen) { value in
  ///       #expect(value >= 0.0 && value <= 100.0)
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.double``, ``Gen.probability``, ``Gen.float(in:)``
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
  /// Generate ASCII strings with printable ASCII characters.
  ///
  /// Produces random strings from the printable ASCII character set (space through tilde, codes 32-126)
  /// with variable length determined by the size parameter. This is suitable for testing text processing
  /// and parsing functionality.
  ///
  /// **Character Set:**
  /// - Range: ASCII 32 (space) through ASCII 126 (tilde)
  /// - Includes: Spaces, punctuation, letters, digits
  /// - Excludes: Control characters and non-ASCII Unicode
  ///
  /// **Generation Strategy:**
  /// - Length: 0 to size parameter (uniform distribution)
  /// - Character selection: Uniform from printable ASCII range
  /// - Default size 10 produces strings typically 0-10 characters
  ///
  /// **Shrinking Strategy:**
  /// Shrinks strings toward empty string (simplest):
  /// 1. Shrinks to empty string ""
  /// 2. Removes first character
  /// 3. Removes last character
  /// 4. Removes middle character
  ///
  /// **Use Cases:**
  /// - Testing ASCII-only text processing
  /// - Network protocol message generation
  /// - Command-line argument testing
  /// - Legacy ASCII-only systems
  ///
  /// - Returns: Generator producing ASCII String values with built-in shrinking
  ///
  /// - Note: For Unicode strings including emoji and international characters, use ``Gen.string``
  ///   or ``Gen.unicodeString``. For specific character sets, use custom generators with map composition.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<String>.asciiString
  ///   let property = Property(generator: gen) { str in
  ///       #expect(str.allSatisfy { $0.asciiValue != nil })
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.string``, ``Gen.letter``, ``Gen.digit``
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
  /// Generate random Universally Unique Identifiers (UUIDs).
  ///
  /// Produces random version 4 UUIDs suitable for testing systems that depend on unique identifiers.
  /// Each generated UUID is cryptographically random and has negligible probability of collision.
  ///
  /// **UUID Generation:**
  /// - Type: Version 4 (random)
  /// - Format: Standard 8-4-4-4-12 hexadecimal format
  /// - Probability of collision: Vanishingly small (see birthday paradox)
  ///
  /// **Shrinking Strategy:**
  /// UUIDs do not shrink meaningfully. Each UUID is equally minimal; shrinking returns an empty sequence.
  /// This is appropriate because UUIDs are identifiers, not quantitative values with meaningful ordering.
  ///
  /// **Use Cases:**
  /// - Testing unique identifier requirements
  /// - Database record ID generation
  /// - Request tracing and correlation IDs
  /// - Testing uniqueness constraints
  /// - Stream processing event IDs
  ///
  /// - Returns: Generator producing random UUID values with no shrinking
  ///
  /// - Note: Each generation creates a new UUID; size parameter is ignored.
  ///   Suitable for any scale of testing since collisions are astronomically rare.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<UUID>.uuid
  ///   let property = Property(generator: gen) { uuid in
  ///       #expect(uuid.uuidString.count == 36)  // Standard format length
  ///       #expect(uuid.uuidString.split(separator: "-").count == 5)
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.string``, ``Gen.int(in:)``
  public static var uuid: Gen<UUID> {
    Gen<UUID>(
      generate: { _, _ in UUID() },
      shrink: Shrink { _ in [] }  // UUIDs don't shrink meaningfully
    )
  }
}

// MARK: - Character Generators

extension Gen where T == Character {
  /// Generate alphabetic characters from a-z and A-Z.
  ///
  /// Produces random letters from the English alphabet, both lowercase and uppercase,
  /// with uniform probability distribution. Size parameter is ignored.
  ///
  /// **Character Set:**
  /// - Lowercase: a-z (26 characters)
  /// - Uppercase: A-Z (26 characters)
  /// - Total: 52 possible characters
  /// - No accents, diacritics, or non-ASCII letters
  ///
  /// **Generation Strategy:**
  /// - Uniform distribution across all 52 letters
  /// - Size parameter does not affect generation
  /// - Each invocation produces exactly one character
  ///
  /// **Shrinking Strategy:**
  /// Shrinks toward 'a' (first letter alphabetically):
  /// 1. Any letter shrinks to 'a' (simplest)
  /// 2. 'a' shrinks to empty sequence (already minimal)
  ///
  /// **Use Cases:**
  /// - Testing string parsing with letter validation
  /// - Identifier and variable name generation
  /// - Testing case sensitivity
  /// - Building blocks for word/string generators
  ///
  /// - Returns: Generator producing Character values (a-zA-Z) with built-in shrinking
  ///
  /// - Note: For Unicode letters including accents and international characters, use custom generators.
  ///   For digits, use ``Gen.digit``. For mixed alphanumeric, compose with ``Gen.or(_:_:)``.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Character>.letter
  ///   let property = Property(generator: gen) { char in
  ///       #expect(char.isLetter)
  ///       #expect((char >= "a" && char <= "z") || (char >= "A" && char <= "Z"))
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.lowercase``, ``Gen.digit``, ``Gen.string``
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

  /// Generate lowercase letters from a-z.
  ///
  /// Produces random lowercase letters from the English alphabet with uniform probability.
  /// Size parameter is ignored. This is a specialized version of ``Gen.letter`` that excludes uppercase.
  ///
  /// **Character Set:**
  /// - Range: a-z (26 characters)
  /// - All lowercase English letters
  /// - No uppercase, digits, or special characters
  ///
  /// **Generation Strategy:**
  /// - Uniform distribution across 26 letters
  /// - Size parameter does not affect generation
  /// - Each invocation produces exactly one character
  ///
  /// **Shrinking Strategy:**
  /// Shrinks toward 'a':
  /// 1. Any letter shrinks to 'a'
  /// 2. 'a' shrinks to empty sequence (already minimal)
  ///
  /// **Use Cases:**
  /// - Testing case-sensitive text processing
  /// - Lowercase identifier generation
  /// - Testing case-sensitive comparisons
  /// - Building lowercase words or slugs
  ///
  /// - Returns: Generator producing lowercase Character values (a-z) with built-in shrinking
  ///
  /// - Note: For uppercase letters, use custom compositions. For Unicode lowercase, use custom generators.
  ///   For mixed case, compose multiple generators with ``Gen.or(_:_:)``.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Character>.lowercase
  ///   let property = Property(generator: gen) { char in
  ///       #expect(char.isLowercase)
  ///       #expect(char >= "a" && char <= "z")
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.letter``, ``Gen.digit``
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

  /// Generate digit characters from 0-9.
  ///
  /// Produces random decimal digit characters with uniform probability distribution.
  /// Size parameter is ignored. Each character represents a single decimal digit.
  ///
  /// **Character Set:**
  /// - Range: 0-9 (10 characters)
  /// - ASCII codes: 48-57
  /// - No letters, special characters, or negative sign
  ///
  /// **Generation Strategy:**
  /// - Uniform distribution across 10 digits
  /// - Size parameter does not affect generation
  /// - Each invocation produces exactly one character
  ///
  /// **Shrinking Strategy:**
  /// Shrinks toward '0':
  /// 1. Any digit shrinks to '0'
  /// 2. '0' shrinks to empty sequence (already minimal)
  ///
  /// **Use Cases:**
  /// - Testing numeric string parsing
  /// - Phone number generation
  /// - PIN and numeric code testing
  /// - Digit-only field validation
  /// - Building numeric strings or passwords
  ///
  /// - Returns: Generator producing digit Character values (0-9) with built-in shrinking
  ///
  /// - Note: For actual numbers, use ``Gen.int``, ``Gen.double``, etc.
  ///   For mixed alphanumeric, compose with ``Gen.letter`` using ``Gen.or(_:_:)``.
  ///   For hexadecimal digits, create a custom generator from "0-9a-f".
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Character>.digit
  ///   let property = Property(generator: gen) { char in
  ///       #expect(char.isNumber)
  ///       #expect(char >= "0" && char <= "9")
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.letter``, ``Gen.int``, ``Gen.string``
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
