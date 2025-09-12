import Foundation

// MARK: - Array Generators

extension Gen where T == [Any] {
  /// Generate arrays of any element type with comprehensive edge cases
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

        let count = Int.random(in: 0...min(size.value, 100), using: &rng)
        return (0..<count).map { _ in elementGen.generate(&rng, size) }
      },
      shrink: Shrink { array in
        var shrunk: [[Element]] = []

        // Shrink to empty
        if !array.isEmpty {
          shrunk.append([])
        }

        // Remove elements one by one
        for i in array.indices {
          var smaller = array
          smaller.remove(at: i)
          shrunk.append(smaller)
        }

        // Shrink elements individually
        for (index, element) in array.enumerated() {
          for shrunkElement in elementGen.shrink.shrink(element) {
            var newArray = array
            newArray[index] = shrunkElement
            shrunk.append(newArray)
          }
        }

        // Shrink by halving
        if array.count > 2 {
          let half = array.count / 2
          shrunk.append(Array(array.prefix(half)))
          shrunk.append(Array(array.suffix(half)))
        }

        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

// MARK: - Set Generators

extension Gen where T == Set<AnyHashable> {
  /// Generate sets with comprehensive coverage
  public static func set<Element: Hashable>(_ elementGen: Gen<Element>) -> Gen<Set<Element>> {
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
        let targetCount = Int.random(in: 0...min(size.value, 50), using: &rng)
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

extension Gen where T == [AnyHashable: Any] {
  /// Generate dictionaries with comprehensive coverage
  public static func dictionary<Key: Hashable, Value>(
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

        let targetCount = Int.random(in: 0...min(size.value, 50), using: &rng)
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

        // Shrink to empty
        if !dict.isEmpty {
          shrunk.append([:])
        }

        // Remove key-value pairs one by one
        for key in dict.keys {
          var smaller = dict
          smaller.removeValue(forKey: key)
          shrunk.append(smaller)
        }

        // Shrink keys and values individually
        for (key, value) in dict {
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

        return shrunk.removingDuplicatesGeneric()
      }
    )
  }
}

// MARK: - Range Generators

extension Gen where T == Range<Int> {
  /// Generate Range<Int> with comprehensive edge cases
  public static var intRange: Gen<Range<Int>> {
    Gen<Range<Int>>(
      generate: { rng, size in
        let maxRange = min(size.value * 10, 1000)
        let start = Int.random(in: -maxRange...maxRange, using: &rng)
        let length = Int.random(in: 0...min(size.value, 100), using: &rng)
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
  /// Generate ClosedRange<Int> with comprehensive edge cases
  public static var intClosedRange: Gen<ClosedRange<Int>> {
    Gen<ClosedRange<Int>>(
      generate: { rng, size in
        let maxRange = min(size.value * 10, 1000)
        let start = Int.random(in: -maxRange...maxRange, using: &rng)
        let length = Int.random(in: 0...min(size.value, 100), using: &rng)
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
  /// Generate PartialRangeFrom<Int>
  public static var intPartialRangeFrom: Gen<PartialRangeFrom<Int>> {
    Gen<PartialRangeFrom<Int>>(
      generate: { rng, size in
        let maxRange = min(size.value * 10, 1000)
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
  /// Generate PartialRangeUpTo<Int>
  public static var intPartialRangeUpTo: Gen<PartialRangeUpTo<Int>> {
    Gen<PartialRangeUpTo<Int>>(
      generate: { rng, size in
        let maxRange = min(size.value * 10, 1000)
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
  /// Generate PartialRangeThrough<Int>
  public static var intPartialRangeThrough: Gen<PartialRangeThrough<Int>> {
    Gen<PartialRangeThrough<Int>>(
      generate: { rng, size in
        let maxRange = min(size.value * 10, 1000)
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

extension Gen where T == ArraySlice<Any> {
  /// Generate ArraySlice with comprehensive coverage
  public static func arraySlice<Element>(_ elementGen: Gen<Element>) -> Gen<ArraySlice<Element>> {
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
    return Array(self.prefix(maxSize))
  }

  // For types that don't conform to Equatable, just limit size
  func removingDuplicatesGeneric() -> [Element] {
    return self.limitingSize()
  }
}
