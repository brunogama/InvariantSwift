import Foundation

extension Gen where T == String {
  /// Generates random strings of specified length using the given character set.
  ///
  /// - Parameters:
  ///   - charSet: The set of characters to choose from. Default is alphanumeric.
  ///   - length: The generator for string length. Default is up to size complexity.
  /// - Returns: A string generator.
  public static func string(
    of charSet: CharacterSet = .alphanumerics,
    length: Gen<Int>? = nil
  ) -> Gen<String> {
    let lengthGen = length ?? Gen<Int> { rng, size in Int.random(in: 0...size.value, using: &rng) }

    return lengthGen.flatMap { len in
      Gen<String> { rng, _ in
        let chars = charSet.allCharacters
        guard !chars.isEmpty else { return "" }
        return String((0..<len).map { _ in chars.randomElement(using: &rng)! })
      }
    }
  }

  /// Alias for alphanumeric string generator.
  public static var string: Gen<String> {
    string()
  }
}

extension Gen {
  /// Generates a constant value regardless of RNG state or size.
  public static func constant(_ value: T) -> Gen<T> {
    .pure(value)
  }
}

extension CharacterSet {
  /// Extract all characters from the set for random selection.
  /// Note: This is a simplified implementation for standard character sets.
  fileprivate var allCharacters: [Character] {
    // Basic implementation for common character sets
    if self == .alphanumerics {
      return Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    } else if self == .letters {
      return Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    } else if self == .decimalDigits {
      return Array("0123456789")
    }

    // Fallback for custom sets
    var chars: [Character] = []
    for plane: UInt8 in 0...16 {
      // swiftlint:disable:next for_where
      if self.hasMember(inPlane: plane) {
        let p = UInt32(plane) << 16
        for codePoint in p...(p + 0xFFFF) {
          if let scalar = UnicodeScalar(codePoint), self.contains(scalar) {
            chars.append(Character(scalar))
          }
        }
      }
    }
    return chars
  }
}
