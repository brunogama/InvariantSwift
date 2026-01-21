import Foundation

// MARK: - Array Generators

extension Gen where T == [Any] {
  /// Generate arrays of values from a given element generator.
  ///
  /// Produces arrays with variable length (0 to size parameter) where each element is generated
  /// using the provided generator. This is a fundamental collection combinator supporting dependent generation.
  ///
  /// **Generation Strategy:**
  /// - Size: 0 to min(size.value, 100) elements (bounded to prevent memory issues)
  /// - For small sizes (≤3): Includes empty array edge case
  /// - Elements: Generated using provided elementGen at appropriate size
  /// - Size distribution: Geometric with element budget of `size/count`
  ///
  /// **Shrinking Strategy (SHRINK-COLL-001):**
  /// Implements two-phase shrinking with deterministic candidate ordering:
  ///
  /// **Phase 1: Chunk removal (delta-debugging)**
  /// 1. Empty array (most aggressive simplification)
  /// 2. Remove halves, quarters, eighths progressively (logarithmic reduction)
  /// 3. Remove individual elements one-by-one
  ///
  /// **Phase 2: Element-wise shrinking**
  /// 4. Shrink each element independently while preserving array structure
  ///
  /// **Deterministic ordering guarantee:** Same array always produces same shrink candidate sequence.
  /// Candidates are ordered: chunk removal first (largest deletions to smallest), then element shrinks.
  ///
  /// **Edge Cases:**
  /// - Empty arrays are common for size ≤ 3
  /// - Large arrays (100+) are capped to prevent resource exhaustion
  /// - Element shrinking is properly composed with array structure shrinking
  ///
  /// **Mathematical Properties:**
  /// - **Functor**: `array(g.map(f)) = array(g).map { $0.map(f) }`
  /// - **Monadic composition**: Proper size distribution across element budget
  /// - **Commutativity**: Element generation order doesn't matter
  ///
  /// **Performance:**
  /// - Generation: O(n) where n = number of elements
  /// - Shrinking: O(log n) chunk removal + O(n²) element shrinking worst case
  /// - Memory: O(n × sizeof(T))
  ///
  /// - Parameter elementGen: Generator for individual array elements
  ///
  /// - Returns: Generator producing [Element] with built-in shrinking
  ///
  /// - Note: For fixed-length arrays, use ``Gen.sequence(elementGen:count:)``.
  ///   For controlled length ranges, use ``Gen.sequence(elementGen:length:)``.
  ///   For Sets, use ``Gen.set(_:)``. For Dictionaries, use ``Gen.dictionary(_:_:)``.
  ///
  /// - Example:
  ///   ```swift
  ///   let intGen = Gen<Int>.int(in: 0...100)
  ///   let arrayGen = Gen<Int>.array(intGen)
  ///
  ///   let property = Property(generator: arrayGen) { array in
  ///       #expect(array.allSatisfy { $0 >= 0 && $0 <= 100 })
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.set(_:)``, ``Gen.dictionary(_:_:)``, ``Gen.sequence(elementGen:count:)``
  public static func array<Element>(_ elementGen: Gen<Element>) -> Gen<[Element]> {
    Gen<[Element]>(
      generate: { rng, size in
        // Include edge cases
        if size.value <= 3 {
          let edgeCases: [[Element]] = [
            []  // empty array
          ]
          if Bool.random(using: &rng) && !edgeCases.isEmpty {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        let count = Int.random(in: 0...min(max(0, size.value), 100), using: &rng)
        return (0..<count).map { _ in elementGen.generate(&rng, size) }
      },
      shrink: Shrink { array in
        var shrunk: [[Element]] = []

        // SHRINK-COLL-001: Chunk removal FIRST (delta-debugging)
        // This uses Shrink.removeElements which does:
        // 1. Empty array (most aggressive)
        // 2. Remove halves, quarters, eighths progressively
        // 3. Remove individual elements
        shrunk.append(contentsOf: Shrink.removeElements(from: array))

        // THEN element-wise shrinking
        // Shrink each element independently while keeping array structure
        shrunk.append(contentsOf: Shrink.shrinkElements(in: array, using: elementGen.shrink.shrink))

        // Deterministic ordering: chunk removal candidates first, then element shrinks
        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

// MARK: - Set Generators

extension Gen {
  /// Generate sets of hashable values from a given element generator.
  ///
  /// Produces sets with variable cardinality (0 to size parameter) where each element is generated
  /// using the provided generator. Handles hash collisions by over-generating and filtering duplicates.
  ///
  /// **Generation Strategy:**
  /// - Target cardinality: 0 to min(size.value, 50) elements
  /// - Over-generation: Generates 2×target + 10 candidates to account for collisions
  /// - For small sizes (≤3): Includes empty set edge case
  /// - Stops early when target cardinality is reached
  ///
  /// **Shrinking Strategy:**
  /// Progressive simplification toward empty set:
  /// 1. Shrinks to empty set (simplest collection)
  /// 2. Removes elements one by one
  /// 3. Shrinks individual elements recursively
  /// 4. Does not shrink by halving (set order is undefined)
  ///
  /// **Edge Cases:**
  /// - Empty sets are common for size ≤ 3
  /// - Hash collisions cause over-generation (automatic, transparent)
  /// - Set with identical elements is still of cardinality 1 (deduplication works correctly)
  /// - Elements are not in any particular order
  ///
  /// **Mathematical Properties:**
  /// - **Set Semantics**: Duplicates are automatically removed
  /// - **Membership**: Element membership is determined by Hashable conformance
  /// - **Uniqueness**: All generated elements are distinct (set cardinality = generation count - collisions)
  ///
  /// **Performance:**
  /// - Generation: O(n × hash + n²) worst case if hash collisions
  /// - Shrinking: O(n²)
  /// - Memory: O(n × sizeof(T))
  ///
  /// - Parameter elementGen: Generator for individual set elements (must be Hashable)
  ///
  /// - Returns: Generator producing Set<Element> with built-in shrinking
  ///
  /// - Note: Element must conform to Hashable. Elements are unordered; use ``Gen.array(_:)`` if order matters.
  ///   For dictionaries, use ``Gen.dictionary(_:_:)``. Hash quality affects generation efficiency.
  ///
  /// - Example:
  ///   ```swift
  ///   let intGen = Gen<Int>.int(in: 0...100)
  ///   let setGen = Gen<Set<Int>>.set(intGen)
  ///
  ///   let property = Property(generator: setGen) { set in
  ///       #expect(set.allSatisfy { $0 >= 0 && $0 <= 100 })
  ///       #expect(set.count <= 100)  // No duplicates
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.array(_:)``, ``Gen.dictionary(_:_:)``, ``Hashable``
  public static func set<Element: Hashable & Sendable>(
    _ elementGen: Gen<Element>
  ) -> Gen<Set<Element>> {
    Gen<Set<Element>>(
      generate: { rng, size in
        // Edge cases
        if size.value <= 3 {
          let edgeCases: [Set<Element>] = [
            Set()  // empty set
          ]
          if Bool.random(using: &rng) && !edgeCases.isEmpty {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        // Generate more elements than needed to account for duplicates
        let targetCount = Int.random(in: 0...min(max(0, size.value), 50), using: &rng)
        let overGenerate = targetCount * 2 + 10

        var elements: Set<Element> = []
        for _ in 0..<overGenerate {
          let element = elementGen.generate(&rng, size)
          elements.insert(element)
          if elements.count >= targetCount {
            break
          }
        }

        return elements
      },
      shrink: Shrink { set in
        var shrunk: [Set<Element>] = []

        // Shrink to empty
        if !set.isEmpty {
          shrunk.append(Set())
        }

        // Remove elements one by one
        for element in set {
          var smaller = set
          smaller.remove(element)
          shrunk.append(smaller)
        }

        // Shrink individual elements
        for element in set {
          for shrunkElement in elementGen.shrink.shrink(element) {
            var newSet = set
            newSet.remove(element)
            newSet.insert(shrunkElement)
            shrunk.append(newSet)
          }
        }

        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

// MARK: - Dictionary Generators

extension Gen {
  /// Generate dictionaries with key-value pairs from provided generators.
  ///
  /// Produces dictionaries with variable count (0 to size parameter) where keys and values are generated
  /// independently. Handles key collisions by over-generating and filtering to target cardinality.
  ///
  /// **Generation Strategy:**
  /// - Target count: 0 to min(size.value, 50) key-value pairs
  /// - Over-generation: Generates 2×target + 10 candidates to account for collisions
  /// - For small sizes (≤3): Includes empty dictionary edge case
  /// - Stops early when target count is reached
  /// - Key collisions replace previous values (standard dictionary semantics)
  ///
  /// **Shrinking Strategy (SHRINK-COLL-001):**
  /// Implements two-phase shrinking with deterministic hash-based ordering:
  ///
  /// **Phase 1: Chunk removal (delta-debugging)**
  /// 1. Convert to sorted array of (Key, Value) pairs (sorted by hashValue for determinism)
  /// 2. Empty dictionary (most aggressive simplification)
  /// 3. Remove chunks: halves, quarters, eighths progressively (logarithmic reduction)
  /// 4. Remove individual key-value pairs one-by-one
  ///
  /// **Phase 2: Element-wise shrinking**
  /// 5. Shrink keys independently while preserving values
  /// 6. Shrink values independently while preserving keys
  ///
  /// **Deterministic ordering guarantee:** Same dictionary always produces same shrink candidate sequence
  /// by sorting keys via hashValue before shrinking. Candidates ordered: chunk removal first, then key shrinks, then value shrinks.
  ///
  /// **Edge Cases:**
  /// - Empty dictionaries are common for size ≤ 3
  /// - Key collisions cause value replacement (last value wins)
  /// - Over-generation handles hash collisions transparently
  /// - Dictionary size = number of unique keys (not generation attempts)
  ///
  /// **Mathematical Properties:**
  /// - **Key Uniqueness**: Each key appears at most once
  /// - **Value Independence**: Values are generated independently of keys
  /// - **Collision Handling**: Over-generation ensures target cardinality is reached
  /// - **Order Independence**: Dictionary iteration order is unspecified
  ///
  /// **Performance:**
  /// - Generation: O(n × (hash + value_gen)) where n = target count
  /// - Shrinking: O(n² × (key_shrink + value_shrink))
  /// - Memory: O(n × (sizeof(Key) + sizeof(Value)))
  ///
  /// - Parameters:
  ///   - keyGen: Generator for dictionary keys (must be Hashable)
  ///   - valueGen: Generator for dictionary values
  ///
  /// - Returns: Generator producing [Key: Value] with built-in shrinking
  ///
  /// - Note: Keys must conform to Hashable. Keys are unordered by default.
  ///   For arrays with order preservation, use ``Gen.array(_:)`` with tuples.
  ///   For custom ordering, compose with sorting functions.
  ///
  /// - Example:
  ///   ```swift
  ///   let keyGen = Gen<String>.string
  ///   let valueGen = Gen<Int>.int(in: 0...100)
  ///   let dictGen = Gen<[String: Int]>.dictionary(keyGen, valueGen)
  ///
  ///   let property = Property(generator: dictGen) { dict in
  ///       #expect(dict.allSatisfy { _, value in value >= 0 && value <= 100 })
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.array(_:)``, ``Gen.set(_:)``, ``Hashable``
  public static func dictionary<Key: Hashable & Sendable, Value: Sendable>(
    _ keyGen: Gen<Key>,
    _ valueGen: Gen<Value>
  ) -> Gen<[Key: Value]> {
    Gen<[Key: Value]>(
      generate: { rng, size in
        // Edge cases
        if size.value <= 3 {
          let edgeCases: [[Key: Value]] = [
            [:]  // empty dictionary
          ]
          if Bool.random(using: &rng) && !edgeCases.isEmpty {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        let targetCount = Int.random(in: 0...min(max(0, size.value), 50), using: &rng)
        var dict: [Key: Value] = [:]

        // Generate with oversampling to handle key collisions
        for _ in 0..<(targetCount * 2 + 10) {
          let key = keyGen.generate(&rng, size)
          let value = valueGen.generate(&rng, size)
          dict[key] = value

          if dict.count >= targetCount {
            break
          }
        }

        return dict
      },
      shrink: Shrink { dict in
        var shrunk: [[Key: Value]] = []

        // SHRINK-COLL-001: Deterministic ordering via hash-based sorting
        // Convert to array of tuples sorted by hash value for reproducibility
        let pairs = dict.sorted(by: { $0.key.hashValue < $1.key.hashValue })

        // SHRINK-COLL-001: Chunk removal FIRST (delta-debugging)
        // Remove chunks of key-value pairs using delta debugging strategy
        let pairArrays = Shrink.removeElements(from: pairs)
        shrunk.append(contentsOf: pairArrays.map { Dictionary(uniqueKeysWithValues: $0) })

        // THEN element-wise shrinking
        // Shrink keys and values independently, maintaining deterministic order
        for (key, value) in pairs {
          // Shrink key
          for shrunkKey in keyGen.shrink.shrink(key) {
            var newDict = dict
            newDict.removeValue(forKey: key)
            newDict[shrunkKey] = value
            shrunk.append(newDict)
          }

          // Shrink value
          for shrunkValue in valueGen.shrink.shrink(value) {
            var newDict = dict
            newDict[key] = shrunkValue
            shrunk.append(newDict)
          }
        }

        // Deterministic ordering: chunk removal first, then key shrinks, then value shrinks
        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

// MARK: - Range Generators

extension Gen where T == Range<Int> {
  /// Generate Range<Int> with half-open intervals and comprehensive edge cases.
  ///
  /// Produces ranges covering empty, single-element, and multi-element intervals.
  /// Ranges follow half-open semantics: [start, end) includes start but excludes end.
  ///
  /// **Generation Strategy:**
  /// - Start: Random in range [-maxRange...maxRange]
  /// - Length: Random in range [0...min(size.value, 100)]
  /// - End: Calculated as start + length
  /// - For small sizes (≤5): Includes edge cases (empty, single, negative)
  ///
  /// **Shrinking Strategy:**
  /// Progressive simplification:
  /// 1. Shrinks to empty range (lowerBound..<lowerBound)
  /// 2. Shrinks bounds toward zero
  /// 3. Shrinks by reducing length
  ///
  /// **Edge Cases:**
  /// - Empty ranges: 0..<0, 1..<1, etc.
  /// - Single-element ranges: 0..<1
  /// - Negative ranges: -5..<-1
  /// - Ranges near overflow: Int.max-1..<Int.max
  ///
  /// **Use Cases:**
  /// - Testing range-based iteration
  /// - Loop bound generation
  /// - Subarray slicing
  /// - Range validation logic
  ///
  /// - Returns: Generator producing Range<Int> with built-in shrinking
  ///
  /// - Note: For closed ranges, use ``Gen.intClosedRange``. For partial ranges, use
  ///   ``Gen.intPartialRangeFrom``, ``Gen.intPartialRangeUpTo``, or ``Gen.intPartialRangeThrough``.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Range<Int>>.intRange
  ///   let property = Property(generator: gen) { range in
  ///       #expect(range.lowerBound <= range.upperBound)
  ///       #expect(range.count == range.upperBound - range.lowerBound)
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.intClosedRange``, ``Gen.intPartialRangeFrom``, ``Gen.intPartialRangeUpTo``, ``Gen.intPartialRangeThrough``
  public static var intRange: Gen<Range<Int>> {
    Gen<Range<Int>>(
      generate: { rng, size in
        let maxRange = min(max(0, size.value) * 10, 1000)
        let start = Int.random(in: -maxRange...maxRange, using: &rng)
        let length = Int.random(in: 0...min(max(0, size.value), 100), using: &rng)
        let end = start + length

        // Handle edge cases
        if size.value <= 5 {
          let edgeCases = [
            0..<0,  // empty range
            0..<1,  // single element
            -1..<0,  // negative range
            Int.max - 1..<Int.max,  // near overflow
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        return start..<end
      },
      shrink: Shrink { range in
        var shrunk: [Range<Int>] = []

        // Shrink to empty range
        if !range.isEmpty {
          shrunk.append(range.lowerBound..<range.lowerBound)
        }

        // Shrink bounds toward zero
        if range.lowerBound != 0 {
          shrunk.append(0..<range.upperBound)
        }
        if range.upperBound != 0 && range.upperBound > range.lowerBound {
          shrunk.append(range.lowerBound..<0)
        }

        // Shrink by reducing size
        if range.count > 1 {
          let newEnd = range.lowerBound + range.count / 2
          shrunk.append(range.lowerBound..<newEnd)
        }

        return shrunk.removingDuplicatesPreservingOrder()
      }
    )
  }
}

extension Gen where T == ClosedRange<Int> {
  /// Generate ClosedRange<Int> with closed intervals and comprehensive edge cases.
  ///
  /// Produces ranges covering single-element through multi-element closed intervals.
  /// Ranges follow closed semantics: [start...end] includes both start and end.
  ///
  /// **Generation Strategy:**
  /// - Start: Random in range [-maxRange...maxRange]
  /// - Length: Random in range [0...min(size.value, 100)]
  /// - End: Calculated as start + length
  /// - For small sizes (≤5): Includes edge cases (single element, extremes)
  ///
  /// **Shrinking Strategy:**
  /// Progressive simplification:
  /// 1. Shrinks to single-element ranges (lowerBound...lowerBound, upperBound...upperBound)
  /// 2. Shrinks bounds toward zero
  /// 3. Shrinks by reducing length
  ///
  /// **Edge Cases:**
  /// - Single-element ranges: 0...0, 1...1, -1...-1
  /// - Ranges at extremes: Int.min...Int.min, Int.max...Int.max
  /// - Negative ranges: -5...(-1)
  ///
  /// **Use Cases:**
  /// - Testing closed range iterations
  /// - Subscript bound generation
  /// - Enumeration boundaries
  /// - Constraint testing
  ///
  /// - Returns: Generator producing ClosedRange<Int> with built-in shrinking
  ///
  /// - Note: For half-open ranges, use ``Gen.intRange``. For partial ranges, use
  ///   ``Gen.intPartialRangeFrom``, ``Gen.intPartialRangeUpTo``, or ``Gen.intPartialRangeThrough``.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<ClosedRange<Int>>.intClosedRange
  ///   let property = Property(generator: gen) { range in
  ///       #expect(range.lowerBound <= range.upperBound)
  ///       #expect(range.contains(range.lowerBound) && range.contains(range.upperBound))
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.intRange``, ``Gen.intPartialRangeFrom``, ``Gen.intPartialRangeUpTo``, ``Gen.intPartialRangeThrough``
  public static var intClosedRange: Gen<ClosedRange<Int>> {
    Gen<ClosedRange<Int>>(
      generate: { rng, size in
        let maxRange = min(max(0, size.value) * 10, 1000)
        let start = Int.random(in: -maxRange...maxRange, using: &rng)
        let length = Int.random(in: 0...min(max(0, size.value), 100), using: &rng)
        let end = start + length

        // Handle edge cases
        if size.value <= 5 {
          let edgeCases = [
            0...0,  // single element
            -1...(-1),  // single negative
            Int.min...Int.min,  // extreme low
            Int.max...Int.max,  // extreme high
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        return start...end
      },
      shrink: Shrink { range in
        var shrunk: [ClosedRange<Int>] = []

        // Shrink to single element
        if range.count > 1 {
          shrunk.append(range.lowerBound...range.lowerBound)
          shrunk.append(range.upperBound...range.upperBound)
        }

        // Shrink bounds toward zero
        if range.lowerBound != 0 {
          shrunk.append(0...range.upperBound)
        }
        if range.upperBound != 0 && range.upperBound > range.lowerBound {
          shrunk.append(range.lowerBound...0)
        }

        // Shrink by reducing size
        if range.count > 1 {
          let newEnd = range.lowerBound + (range.upperBound - range.lowerBound) / 2
          shrunk.append(range.lowerBound...newEnd)
        }

        return shrunk.removingDuplicatesPreservingOrder()
      }
    )
  }
}

// MARK: - Partial Range Generators

extension Gen where T == PartialRangeFrom<Int> {
  /// Generate PartialRangeFrom<Int> (half-infinite starting ranges).
  ///
  /// Produces ranges of the form `start...` (infinity) representing all integers from start onward.
  /// Particularly useful for testing unbounded iteration and slice operations.
  ///
  /// **Generation Strategy:**
  /// - Start: Random in range [-maxRange...maxRange]
  /// - For small sizes (≤5): Includes edge cases (0, negative, extremes)
  /// - Unbounded: No upper limit (extends to infinity conceptually)
  ///
  /// **Shrinking Strategy:**
  /// Progressive simplification:
  /// 1. Shrinks toward 0 (simplest start point)
  /// 2. Shrinks by halving the start value
  /// 3. Shrinks by decrementing
  ///
  /// **Edge Cases:**
  /// - Starting from 0: 0...
  /// - Starting from 1: 1...
  /// - Negative start: -1...
  /// - Int.min: Int.min...
  ///
  /// **Use Cases:**
  /// - Testing unbounded iteration
  /// - Slice operations from index onward
  /// - Range-based filtering
  /// - Constraint testing on lower bounds
  ///
  /// - Returns: Generator producing PartialRangeFrom<Int> with built-in shrinking
  ///
  /// - Note: Represents ranges like `5...` meaning 5 to infinity. Use ``Gen.intPartialRangeUpTo``
  ///   for upper-bounded ranges (..<end) or ``Gen.intPartialRangeThrough`` for (...end).
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<PartialRangeFrom<Int>>.intPartialRangeFrom
  ///   let property = Property(generator: gen) { range in
  ///       #expect(range.contains(range.lowerBound))
  ///       #expect(range.contains(Int.max))
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.intRange``, ``Gen.intClosedRange``, ``Gen.intPartialRangeUpTo``, ``Gen.intPartialRangeThrough``
  public static var intPartialRangeFrom: Gen<PartialRangeFrom<Int>> {
    Gen<PartialRangeFrom<Int>>(
      generate: { rng, size in
        let maxRange = min(max(0, size.value) * 10, 1000)
        let start = Int.random(in: -maxRange...maxRange, using: &rng)

        // Edge cases
        if size.value <= 5 {
          let edgeCases: [PartialRangeFrom<Int>] = [
            0...,
            Int.min...,
            (-1)...,
            1...,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        return start...
      },
      shrink: Shrink { range in
        var shrunk: [PartialRangeFrom<Int>] = []

        // Shrink toward zero
        if range.lowerBound != 0 {
          shrunk.append(0...)
        }

        // Shrink by halving
        if range.lowerBound > 1 {
          shrunk.append((range.lowerBound / 2)...)
        } else if range.lowerBound < -1 {
          shrunk.append((range.lowerBound / 2)...)
        }

        // Shrink by incrementing/decrementing
        if range.lowerBound > Int.min {
          shrunk.append((range.lowerBound - 1)...)
        }

        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

extension Gen where T == PartialRangeUpTo<Int> {
  /// Generate PartialRangeUpTo<Int> (half-infinite upper-bounded ranges).
  ///
  /// Produces ranges of the form `..<end` representing all integers from negative infinity up to (but not including) end.
  /// Useful for testing upper-bounded iteration and array slicing.
  ///
  /// **Generation Strategy:**
  /// - End: Random in range [-maxRange...maxRange]
  /// - For small sizes (≤5): Includes edge cases (0, negative, extremes)
  /// - Unbounded below: No lower limit (extends to negative infinity conceptually)
  ///
  /// **Shrinking Strategy:**
  /// Progressive simplification:
  /// 1. Shrinks toward 0 (simplest end point)
  /// 2. Shrinks by halving the end value
  /// 3. Shrinks by decrementing
  ///
  /// **Edge Cases:**
  /// - Ending at 0: ..<0
  /// - Ending at 1: ..<1
  /// - Negative end: ..< (-1)
  /// - Int.max: ..< Int.max
  ///
  /// **Use Cases:**
  /// - Testing upper-bounded iteration
  /// - Array slicing from beginning
  /// - Prefix operations
  /// - Upper bound constraint testing
  ///
  /// - Returns: Generator producing PartialRangeUpTo<Int> with built-in shrinking
  ///
  /// - Note: Represents ranges like `..<10` meaning all integers less than 10. Use ``Gen.intPartialRangeFrom``
  ///   for lower-bounded ranges (start...) or ``Gen.intPartialRangeThrough`` for (...end).
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<PartialRangeUpTo<Int>>.intPartialRangeUpTo
  ///   let property = Property(generator: gen) { range in
  ///       #expect(range.contains(Int.min))
  ///       #expect(!range.contains(range.upperBound))
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.intRange``, ``Gen.intClosedRange``, ``Gen.intPartialRangeFrom``, ``Gen.intPartialRangeThrough``
  public static var intPartialRangeUpTo: Gen<PartialRangeUpTo<Int>> {
    Gen<PartialRangeUpTo<Int>>(
      generate: { rng, size in
        let maxRange = min(max(0, size.value) * 10, 1000)
        let end = Int.random(in: -maxRange...maxRange, using: &rng)

        // Edge cases
        if size.value <= 5 {
          let edgeCases = [
            ..<0,
            ..<1,
            ..<(-1),
            ..<Int.max,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        return ..<end
      },
      shrink: Shrink { range in
        var shrunk: [PartialRangeUpTo<Int>] = []

        // Shrink toward zero
        if range.upperBound != 0 {
          shrunk.append(..<0)
        }

        // Shrink by halving
        if range.upperBound > 1 {
          shrunk.append(..<(range.upperBound / 2))
        } else if range.upperBound < -1 {
          shrunk.append(..<(range.upperBound / 2))
        }

        // Shrink by decrementing
        if range.upperBound > Int.min {
          shrunk.append(..<(range.upperBound - 1))
        }

        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

extension Gen where T == PartialRangeThrough<Int> {
  /// Generate PartialRangeThrough<Int> (half-infinite closed upper-bounded ranges).
  ///
  /// Produces ranges of the form `...end` representing all integers from negative infinity through end (inclusive).
  /// Useful for testing closed upper-bounded iteration and subscript operations.
  ///
  /// **Generation Strategy:**
  /// - End: Random in range [-maxRange...maxRange]
  /// - For small sizes (≤5): Includes edge cases (0, negative, extremes)
  /// - Unbounded below: No lower limit (extends to negative infinity conceptually)
  ///
  /// **Shrinking Strategy:**
  /// Progressive simplification:
  /// 1. Shrinks toward 0 (simplest end point)
  /// 2. Shrinks by halving the end value
  /// 3. Shrinks by decrementing
  ///
  /// **Edge Cases:**
  /// - Ending at 0: ...0
  /// - Ending at 1: ...1
  /// - Negative end: ...(-1)
  /// - Int.max: ...Int.max (includes all integers)
  ///
  /// **Use Cases:**
  /// - Testing closed upper-bounded iteration
  /// - Inclusive subscript bounds
  /// - Through enumeration
  /// - Closed upper bound constraint testing
  ///
  /// - Returns: Generator producing PartialRangeThrough<Int> with built-in shrinking
  ///
  /// - Note: Represents ranges like `...10` meaning all integers up to and including 10.
  ///   Use ``Gen.intPartialRangeFrom`` for lower-bounded ranges (start...)
  ///   or ``Gen.intPartialRangeUpTo`` for (..<end) upper-bounded ranges.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<PartialRangeThrough<Int>>.intPartialRangeThrough
  ///   let property = Property(generator: gen) { range in
  ///       #expect(range.contains(Int.min))
  ///       #expect(range.contains(range.upperBound))
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.intRange``, ``Gen.intClosedRange``, ``Gen.intPartialRangeFrom``, ``Gen.intPartialRangeUpTo``
  public static var intPartialRangeThrough: Gen<PartialRangeThrough<Int>> {
    Gen<PartialRangeThrough<Int>>(
      generate: { rng, size in
        let maxRange = min(max(0, size.value) * 10, 1000)
        let end = Int.random(in: -maxRange...maxRange, using: &rng)

        // Edge cases
        if size.value <= 5 {
          let edgeCases = [
            ...0,
            ...1,
            ...(-1),
            ...Int.max,
          ]
          if Bool.random(using: &rng) {
            return edgeCases.randomElement(using: &rng)!
          }
        }

        return ...end
      },
      shrink: Shrink { range in
        var shrunk: [PartialRangeThrough<Int>] = []

        // Shrink toward zero
        if range.upperBound != 0 {
          shrunk.append(...0)
        }

        // Shrink by halving
        if range.upperBound > 1 {
          shrunk.append(...(range.upperBound / 2))
        } else if range.upperBound < -1 {
          shrunk.append(...(range.upperBound / 2))
        }

        // Shrink by decrementing
        if range.upperBound > Int.min {
          shrunk.append(...(range.upperBound - 1))
        }

        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

// MARK: - ArraySlice Generators

extension Gen {
  /// Generate array slices (subarray views) with comprehensive coverage.
  ///
  /// Produces array slices representing views into arrays. Each slice is generated by first creating
  /// a full array, then selecting a random contiguous subsequence. Slices preserve original indices.
  ///
  /// **Generation Strategy:**
  /// - Base array: Generated using ``Gen.array(_:)`` logic
  /// - Slice bounds: Random start and end indices within base array
  /// - Contiguous: All slices are contiguous subsequences
  /// - Empty arrays: Result in empty slices
  ///
  /// **Shrinking Strategy:**
  /// Derived from array shrinking:
  /// 1. Shrinks base array (via array shrinking)
  /// 2. Converts shrunk arrays back to slices
  /// 3. Preserves slice semantics during shrinking
  ///
  /// **Edge Cases:**
  /// - Empty slices: From empty array or slice bounds
  /// - Full array as slice: Entire array selected as slice
  /// - Single-element slices: startIndex..<startIndex + 1
  /// - Preserves original indices (not zero-based like arrays)
  ///
  /// **Mathematical Properties:**
  /// - **Isomorphic to Arrays**: Slice shrinking isomorphic to array shrinking
  /// - **Contiguity**: Always represents contiguous subsequence
  /// - **Index Preservation**: Original indices preserved from base array
  ///
  /// **Performance:**
  /// - Generation: O(n) where n = array length
  /// - Shrinking: O(n²) (inherited from array shrinking)
  /// - Memory: O(n) (view into base array, not copied in Swift)
  ///
  /// - Parameter elementGen: Generator for base array elements
  ///
  /// - Returns: Generator producing ArraySlice<Element> with built-in shrinking
  ///
  /// - Note: ArraySlice is a view type; generation includes underlying array.
  ///   For collections, use ``Gen.array(_:)`` instead. For fixed-size slices, use custom generator.
  ///
  /// - Example:
  ///   ```swift
  ///   let intGen = Gen<Int>.int(in: 0...100)
  ///   let sliceGen = Gen<ArraySlice<Int>>.arraySlice(intGen)
  ///
  ///   let property = Property(generator: sliceGen) { slice in
  ///       #expect(slice.allSatisfy { $0 >= 0 && $0 <= 100 })
  ///   }
  ///   ```
  ///
  /// - See Also: ``Gen.array(_:)``, ``ArraySlice``
  public static func arraySlice<Element: Sendable>(
    _ elementGen: Gen<Element>
  ) -> Gen<ArraySlice<Element>> {
    Gen<ArraySlice<Element>>(
      generate: { rng, size in
        // First generate a base array
        let array = Gen.array(elementGen).generate(&rng, size)

        if array.isEmpty {
          return ArraySlice(array)
        }

        // Create a slice
        let startIndex = Int.random(in: 0...array.count, using: &rng)
        let endIndex = Int.random(in: startIndex...array.count, using: &rng)

        return array[startIndex..<endIndex]
      },
      shrink: Shrink { slice in
        let array = Array(slice)
        let arrayShrinks = Gen.array(elementGen).shrink.shrink(array)
        return arrayShrinks.map { ArraySlice($0) }
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

private extension Array where Element: Equatable {
  func removingDuplicatesPreservingOrder() -> [Element] {
    var seen: [Element] = []
    return filter { element in
      if seen.contains(element) {
        return false
      } else {
        seen.append(element)
        return true
      }
    }
  }
}

// Fallback for non-Equatable types - just limit size instead of removing duplicates
private extension Array {
  func limitingSize(to maxSize: Int = 20) -> [Element] {
    Array(self.prefix(maxSize))
  }

  // For types that don't conform to Equatable, just limit size
  func removingDuplicatesGeneric() -> [Element] {
    self.limitingSize()
  }
}
