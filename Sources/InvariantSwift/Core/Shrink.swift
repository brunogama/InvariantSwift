import Foundation

/// Generates progressively simpler versions of a value to find minimal counterexamples.
///
/// `Shrink<T>` implements coalgebraic shrinking, a fundamental concept in property-based testing.
/// When a property fails on a value, shrinking reduces it to the simplest counterexample that
/// still fails, making failures easier to understand and debug.
///
/// The key insight: Rather than storing all shrunk values, `Shrink` computes them lazily via
/// a function `(T) -> [T]`. This enables efficient exploration of very large shrinking spaces.
///
/// Shrinking strategies vary by type:
/// - **Integers**: 0, half the value, value-1, etc.
/// - **Strings**: Remove characters, reduce length, simplify characters
/// - **Collections**: Remove elements, shrink individual elements
/// - **Custom types**: Domain-specific simplifications
///
/// Mathematical foundation: Shrinking implements a coalgebra, the dual of an algebra.
/// Where an algebra builds up values, a coalgebra unfolds them into simpler forms.
/// This creates a shrinking tree that property-based testers can efficiently search.
///
/// See [Coalgebraic Shrinking](https://dl.acm.org/doi/10.1145/2635868.2635897) for
/// academic background.
///
/// - Example:
///   ```swift
///   let intShrink = Shrink<Int> { n in
///       var candidates: [Int] = []
///       if n > 0 { candidates.append(0) }           // Shrink to zero
///       if n.magnitude > 1 {
///           candidates.append(n / 2)                // Binary search
///           candidates.append(n - 1)                // One less
///       }
///       return candidates
///   }
///
///   let shrunkValues = intShrink.shrink(100)  // [0, 50, 99]
///   ```
///
/// - See Also: ``Gen``, ``Size``
public struct Shrink<T>: @unchecked Sendable {
  /// The function that generates simpler versions of a value.
  ///
  /// Takes a value of type `T` and returns a list of progressively simpler values.
  /// The list should be:
  /// - Non-empty for non-trivial shrinking (empty list means no shrinking)
  /// - Ordered by simplicity (earlier elements are simpler)
  /// - Acyclic (shrinking a shrink should eventually reach a fixed point)
  public let shrink: (T) -> [T]

  /// Initialize a shrinking strategy with a custom shrink function.
  ///
  /// Creates a shrinking strategy by providing a function that generates
  /// simpler versions of values.
  ///
  /// - Parameters:
  ///   - shrink: Function mapping values to lists of simpler versions
  ///
  /// - Example:
  ///   ```swift
  ///   let shrinkInt = Shrink<Int> { n in
  ///       guard n != 0 else { return [] }
  ///       return [0, n / 2]
  ///   }
  ///   ```
  public init(_ shrink: @escaping (T) -> [T]) {
    self.shrink = shrink
  }

  /// No-op shrinking strategy that produces no shrunk values.
  ///
  /// Use when a type cannot or should not be shrunk. This is the default
  /// for many generator types unless explicit shrinking is implemented.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen(generate: myGeneratorFn, shrink: .empty)
  ///   ```
  public static var empty: Shrink<T> {
    Self { _ in [] }
  }

  /// Automatic shrinking strategy that provides a default no-op shrink.
  ///
  /// Use when a type should have automatic shrinking but no specific strategy
  /// is available. This is primarily used by macro-generated code for types
  /// that don't have custom shrinking requirements.
  ///
  /// - Note: This currently returns an empty shrink. Future implementations
  ///   may provide smarter automatic shrinking based on type structure.
  ///
  /// - Example:
  ///   ```swift
  ///   @Arbitrary
  ///   struct Config {
  ///       let debug: Bool
  ///       let timeout: Int
  ///   }
  ///   // Generated code uses Shrink.automatic when no defaults exist
  ///   ```
  public static var automatic: Shrink<T> {
    Self { _ in [] }
  }

  /// Creates a shrinking strategy that shrinks toward a specific target value.
  ///
  /// This strategy generates shrunk values by interpolating between the current
  /// value and the target. For types that support meaningful comparison, this
  /// enables efficient convergence toward the target value.
  ///
  /// - Parameters:
  ///   - target: The value to shrink toward
  ///
  /// - Returns: Shrinking strategy that attempts to produce the target value
  ///
  /// - Note: The current implementation returns only the target as a shrink
  ///   candidate. Callers should ensure the target is a valid minimal value.
  ///
  /// - Example:
  ///   ```swift
  ///   @Arbitrary(shrink: .towards(Config()))
  ///   struct Config {
  ///       let debug: Bool = false
  ///       let timeout: Int = 30
  ///   }
  ///   // Shrinking will attempt to reach Config() as the minimal case
  ///   ```
  public static func towards(_ target: T) -> Shrink<T> {
    Self { _ in [target] }
  }

  /// Combines two shrinking strategies into one for pairs.
  ///
  /// Creates a shrinking strategy for tuples `(T, U)` by combining independent
  /// shrinking strategies for each component. The resulting shrink function
  /// shrinks both elements and returns all possible combinations.
  ///
  /// - Parameters:
  ///   - left: Shrinking strategy for the first component
  ///   - right: Shrinking strategy for the second component
  ///
  /// - Returns: Shrinking strategy for tuples that shrinks both components
  ///
  /// - Example:
  ///   ```swift
  ///   let intShrink = Shrink<Int> { n in n > 0 ? [0, n/2] : [] }
  ///   let stringShrink = Shrink<String> { s in s.isEmpty ? [] : [String(s.dropLast())] }
  ///
  ///   let pairShrink = Shrink.pair(intShrink, stringShrink)
  ///   let shrunk = pairShrink.shrink((10, "hello"))
  ///   // Results include: (0, "hello"), (5, "hello"), (10, "hell"), etc.
  ///   ```
  public static func pair<U>(_ left: Shrink<T>, _ right: Shrink<U>) -> Shrink<(T, U)> {
    Shrink<(T, U)> { pair in
      let leftShrunk = left.shrink(pair.0).map { ($0, pair.1) }
      let rightShrunk = right.shrink(pair.1).map { (pair.0, $0) }
      return leftShrunk + rightShrunk
    }
  }

  /// Monadic bind for dependent shrinking structures.
  ///
  /// - Warning: This method is removed. Use `ShrinkTree.flatMap` for dependent shrinking.
  @available(
    *,
    unavailable,
    message: "Use ShrinkTree.flatMap for correct dependent shrinking."
  )
  public func flatMap<U>(_ f: @escaping (T) -> Shrink<U>) -> Shrink<U> {
    fatalError("Unavailable")
  }

  /// Transforms the shrinking context via a function.
  ///
  /// - Warning: This method is removed. Use `ShrinkTree` for dependent shrinking.
  @available(
    *,
    unavailable,
    message:
      "Use ShrinkTree-based shrinking. Shrink.contramap is mathematically invalid for this type."
  )
  public func contramap<U>(_ f: @escaping (U) -> T) -> Shrink<U> {
    fatalError("Unavailable")
  }

  // MARK: - Shrink Combinators

  /// Shrinks a numeric value toward a target using binary search.
  ///
  /// Generates shrink candidates between the current value and the target,
  /// using binary search for efficient convergence. This is the primary
  /// shrinking strategy for numeric types.
  ///
  /// The shrink sequence for `towards(0, 100)` is approximately:
  /// `[0, 50, 75, 88, 94, 97, 99]` (binary search toward zero)
  ///
  /// - Parameters:
  ///   - target: The value to shrink toward (typically 0 for numbers)
  ///   - value: The current value to shrink
  ///
  /// - Returns: Array of shrink candidates, ordered by simplicity
  ///
  /// - Example:
  ///   ```swift
  ///   Shrink.towards(0, 100)  // [0, 50, 75, 88, 94, 97, 99]
  ///   Shrink.towards(50, 100) // [50, 75, 88, 94, 97, 99]
  ///   Shrink.towards(0, -100) // [0, -50, -75, -88, -94, -97, -99]
  ///   ```
  public static func towards<N: BinaryInteger>(_ target: N, _ value: N) -> [N] {
    guard value != target else { return [] }

    var candidates: [N] = []
    var current = value

    // Always try the target first (most aggressive shrink)
    candidates.append(target)

    // Binary search toward target
    while current != target {
      let next: N
      if current > target {
        next = target + (current - target) / 2
      } else {
        next = target - (target - current) / 2
      }

      if next == current || next == target {
        break
      }

      candidates.append(next)
      current = next
    }

    // Add one step from current value
    if value > target && value - 1 != target {
      candidates.append(value - 1)
    } else if value < target && value + 1 != target {
      candidates.append(value + 1)
    }

    return candidates
  }

  /// Shrinks a floating-point value toward a target using binary search.
  ///
  /// Similar to integer shrinking but handles floating-point precision.
  /// Stops when the difference becomes negligible.
  ///
  /// - Parameters:
  ///   - target: The value to shrink toward (typically 0.0)
  ///   - value: The current value to shrink
  ///
  /// - Returns: Array of shrink candidates
  public static func towards<N: BinaryFloatingPoint>(_ target: N, _ value: N) -> [N] {
    guard value != target else { return [] }

    var candidates: [N] = []
    var current = value

    // Always try the target first
    candidates.append(target)

    // Binary search toward target
    let epsilon: N = 0.0001
    while abs(current - target) > epsilon {
      let next = target + (current - target) / 2

      if abs(next - current) < epsilon || next == target {
        break
      }

      candidates.append(next)
      current = next
    }

    return candidates
  }

  /// Shrinks an array by progressively removing chunks (delta debugging style).
  ///
  /// Produces progressively shorter arrays by:
  /// 1. Trying empty array (most aggressive)
  /// 2. Removing halves, quarters, eighths, etc. (progressive chunk removal)
  /// 3. Removing individual elements
  ///
  /// This delta-debugging strategy quickly finds minimal failing arrays.
  ///
  /// - Parameter array: The array to shrink
  ///
  /// - Returns: Array of shrunk arrays, ordered by simplicity
  ///
  /// - Example:
  ///   ```swift
  ///   Shrink.removeElements(from: [1, 2, 3, 4])
  ///   // Returns: [[], [3,4], [1,2], [2,3,4], [1,3,4], [1,2,4], [1,2,3], ...]
  ///   ```
  public static func removeElements<Element>(from array: [Element]) -> [[Element]] {
    guard !array.isEmpty else { return [] }

    var candidates: [[Element]] = []

    // 1. Try empty first (most aggressive)
    candidates.append([])

    // 2. Delta debugging: remove chunks of decreasing size (N/2, N/4, N/8, ...)
    var chunkSize = array.count / 2
    while chunkSize >= 1 {
      // Generate all arrays with one chunk of this size removed
      var offset = 0
      while offset + chunkSize <= array.count {
        var shrunk = array
        shrunk.removeSubrange(offset..<(offset + chunkSize))
        if !shrunk.isEmpty && shrunk.count != array.count {
          candidates.append(shrunk)
        }
        offset += chunkSize
      }
      chunkSize /= 2
    }

    // 3. Remove individual elements (most fine-grained)
    for i in 0..<array.count {
      var shrunk = array
      shrunk.remove(at: i)
      candidates.append(shrunk)
    }

    return candidates
  }

  /// Shrinks individual elements within an array using a provided shrinker.
  ///
  /// Applies the shrinker to each element independently, producing arrays
  /// where one element is shrunk while others remain unchanged.
  ///
  /// - Parameters:
  ///   - array: The array containing elements to shrink
  ///   - shrinker: Function that shrinks individual elements
  ///
  /// - Returns: Array of shrunk arrays
  ///
  /// - Example:
  ///   ```swift
  ///   let intShrinker: (Int) -> [Int] = { Shrink.towards(0, $0) }
  ///   Shrink.shrinkElements(in: [10, 20], using: intShrinker)
  ///   // Returns arrays like: [[0, 20], [5, 20], [10, 0], [10, 10], ...]
  ///   ```
  public static func shrinkElements<Element>(
    in array: [Element],
    using shrinker: (Element) -> [Element]
  ) -> [[Element]] {
    var candidates: [[Element]] = []

    for i in 0..<array.count {
      let shrunkElements = shrinker(array[i])
      for shrunk in shrunkElements {
        var newArray = array
        newArray[i] = shrunk
        candidates.append(newArray)
      }
    }

    return candidates
  }

  /// Combines multiple shrinking strategies into one.
  ///
  /// Concatenates the results from all provided shrinking functions,
  /// allowing multiple approaches to be tried during shrinking.
  ///
  /// - Parameter shrinks: Array of shrinking functions to combine
  ///
  /// - Returns: Combined shrinking function
  ///
  /// - Example:
  ///   ```swift
  ///   let combinedShrink = Shrink.concat([
  ///       { arr in Shrink.removeElements(from: arr) },
  ///       { arr in Shrink.shrinkElements(in: arr, using: intShrinker) }
  ///   ])
  ///   ```
  public static func concat<U>(_ shrinks: [(U) -> [U]]) -> (U) -> [U] {
    { value in
      shrinks.flatMap { shrink in shrink(value) }
    }
  }

  // MARK: - String Shrinking (S022)

  /// Shrinks a string by removing characters and simplifying character classes.
  ///
  /// Strategy (in order of aggressiveness):
  /// 1. Empty string
  /// 2. Remove halves (first half, second half)
  /// 3. Remove chunks (delta debugging style)
  /// 4. Remove individual characters
  /// 5. Simplify characters (letters → 'a', digits → '0')
  ///
  /// - Parameter string: The string to shrink
  /// - Returns: Array of shrunk strings ordered by simplicity
  ///
  /// - Example:
  ///   ```swift
  ///   Shrink.shrinkString("hello")
  ///   // Returns: ["", "lo", "hel", "ello", "hllo", "helo", "hell", "aello", ...]
  ///   ```
  public static func shrinkString(_ string: String) -> [String] {
    guard !string.isEmpty else { return [] }

    var candidates: [String] = []
    let chars = Array(string)

    // 1. Empty string first
    candidates.append("")

    // 2. Remove halves
    if chars.count > 1 {
      let mid = chars.count / 2
      candidates.append(String(chars.suffix(chars.count - mid)))  // Keep second half
      candidates.append(String(chars.prefix(mid)))  // Keep first half
    }

    // 3. Remove individual characters
    for i in 0..<chars.count {
      var shrunk = chars
      shrunk.remove(at: i)
      candidates.append(String(shrunk))
    }

    // 4. Simplify characters (uppercase → lowercase, letter → 'a', digit → '0')
    for i in 0..<chars.count {
      let char = chars[i]
      var simplified: Character?

      if char.isUppercase {
        simplified = Character(char.lowercased())
      } else if char.isLetter && char != "a" {
        simplified = "a"
      } else if char.isNumber && char != "0" {
        simplified = "0"
      }

      if let s = simplified, s != char {
        var shrunk = chars
        shrunk[i] = s
        candidates.append(String(shrunk))
      }
    }

    return candidates
  }


  /// Creates a Shrink for String values using advanced ShrinkTree-based strategy.
  ///
  /// - Returns: Shrink strategy for strings
  public static var string: Shrink<String> {
    Shrink<String> { string in
      let tree = stringShrinkTree(string)
      return Array(tree.breadthFirst().dropFirst())  // Drop the root (original string)
    }
  }

  // MARK: - Dictionary Shrinking (S022)

  /// Shrinks a dictionary by removing keys and shrinking values.
  ///
  /// Strategy (in order of aggressiveness):
  /// 1. Empty dictionary
  /// 2. Remove halves of keys
  /// 3. Remove individual keys
  /// 4. Shrink individual values (using provided shrinker)
  ///
  /// - Parameters:
  ///   - dict: The dictionary to shrink
  ///   - valueShrink: Function to shrink individual values
  ///
  /// - Returns: Array of shrunk dictionaries
  public static func shrinkDictionary<K: Hashable, V>(
    _ dict: [K: V],
    valueShrink: ((V) -> [V])? = nil
  ) -> [[K: V]] {
    guard !dict.isEmpty else { return [] }

    var candidates: [[K: V]] = []
    let keys = Array(dict.keys)

    // 1. Empty dictionary
    candidates.append([:])

    // 2. Remove halves
    if keys.count > 1 {
      let mid = keys.count / 2
      var firstHalf: [K: V] = [:]
      var secondHalf: [K: V] = [:]

      for (i, key) in keys.enumerated() {
        if i < mid {
          firstHalf[key] = dict[key]
        } else {
          secondHalf[key] = dict[key]
        }
      }

      candidates.append(firstHalf)
      candidates.append(secondHalf)
    }

    // 3. Remove individual keys
    for key in keys {
      var shrunk = dict
      shrunk.removeValue(forKey: key)
      candidates.append(shrunk)
    }

    // 4. Shrink individual values
    if let valueShrink = valueShrink {
      for key in keys {
        if let value = dict[key] {
          for shrunkValue in valueShrink(value) {
            var shrunk = dict
            shrunk[key] = shrunkValue
            candidates.append(shrunk)
          }
        }
      }
    }

    return candidates
  }

  // MARK: - Optional Shrinking (S022)

  /// Shrinks an optional value.
  ///
  /// Strategy:
  /// 1. nil (most aggressive)
  /// 2. Shrinks of the wrapped value
  ///
  /// - Parameters:
  ///   - optional: The optional to shrink
  ///   - valueShrink: Function to shrink the wrapped value
  ///
  /// - Returns: Array of shrunk optionals
  public static func shrinkOptional<U>(
    _ optional: U?,
    valueShrink: (U) -> [U]
  ) -> [U?] {
    guard let value = optional else { return [] }

    var candidates: [U?] = []

    // 1. nil first
    candidates.append(nil)

    // 2. Shrunk values
    for shrunk in valueShrink(value) {
      candidates.append(shrunk)
    }

    return candidates
  }

  // MARK: - Bool Shrinking (S022)

  /// Shrinks a boolean value toward false.
  ///
  /// - Parameter value: The boolean to shrink
  /// - Returns: Array of shrunk booleans (just [false] if true, empty if false)
  public static func shrinkBool(_ value: Bool) -> [Bool] {
    value ? [false] : []
  }

  /// Creates a Shrink for Bool values.
  public static var bool: Shrink<Bool> {
    Shrink<Bool> { shrinkBool($0) }
  }
}

// MARK: - Advanced String Shrinking

/// Creates a structured ShrinkTree for String values with advanced shrinking strategies.
///
/// Strategy order:
/// 1. Reduce length by removing halves (delta-debugging)
/// 2. Reduce length by removing smaller chunks
/// 3. Simplify remaining characters by class (whitespace → alnum → minimal ascii)
///
/// - Parameter string: The string to shrink
/// - Returns: ShrinkTree containing structured shrink candidates
public func stringShrinkTree(_ string: String) -> ShrinkTree<String> {
  ShrinkTree(value: string) {
    var children: [ShrinkTree<String>] = []

    // Add all shrinking strategies
    children.append(contentsOf: stringLengthShrinks(for: string))
    children.append(contentsOf: stringCharacterShrinks(for: string))

    return children
  }
}

/// Generate length-reducing shrinks for a string.
private func stringLengthShrinks(for string: String) -> [ShrinkTree<String>] {
  var children: [ShrinkTree<String>] = []
  let chars = Array(string)

  // 1. Empty string (most aggressive)
  if !string.isEmpty {
    children.append(.leaf(""))
  }

  // 2. Reduce length by removing halves (delta-debugging)
  if chars.count > 1 {
    let mid = chars.count / 2
    children.append(stringShrinkTree(String(chars.suffix(chars.count - mid))))
    children.append(stringShrinkTree(String(chars.prefix(mid))))
  }

  // 3. Reduce length by removing smaller chunks (delta-debugging style)
  var chunkSize = max(1, chars.count / 4)
  while chunkSize >= 1 {
    for start in stride(from: 0, to: chars.count, by: chunkSize) {
      let end = min(start + chunkSize, chars.count)
      if start < end && end < chars.count {
        let before = chars.prefix(start)
        let after = chars.suffix(chars.count - end)
        let shrunk = String(before + after)
        children.append(stringShrinkTree(shrunk))
      }
    }
    chunkSize /= 2
    if chunkSize < 1 { break }
  }

  // 4. Remove individual characters (fallback for small strings)
  if chars.count <= 16 {
    for i in 0..<chars.count {
      var shrunk = chars
      shrunk.remove(at: i)
      children.append(stringShrinkTree(String(shrunk)))
    }
  }

  return children
}

/// Generate character-simplifying shrinks for a string.
private func stringCharacterShrinks(for string: String) -> [ShrinkTree<String>] {
  var children: [ShrinkTree<String>] = []
  let chars = Array(string)

  // 5. Simplify remaining characters by class
  for i in 0..<chars.count {
    if let simplified = simplifiedCharacter(chars[i]), simplified != chars[i] {
      var shrunk = chars
      shrunk[i] = simplified
      children.append(stringShrinkTree(String(shrunk)))
    }
  }

  return children
}

/// Simplify a character to its minimal form.
private func simplifiedCharacter(_ char: Character) -> Character? {
  if char.isWhitespace {
    return " "  // Simplest whitespace
  } else if char.isUppercase {
    return Character(char.lowercased())  // Uppercase → lowercase
  } else if char.isLetter && char != "a" {
    return "a"  // Letter → 'a'
  } else if char.isNumber && char != "0" {
    return "0"  // Digit → '0'
  } else if !char.isASCII && char != "�" {
    return "�"  // Non-ASCII → replacement character
  }
  return nil  // No simplification needed
}
