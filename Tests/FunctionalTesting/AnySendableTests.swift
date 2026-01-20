import Testing
@testable import InvariantCore
@testable import InvariantSwift

@Suite("AnySendable Tests")
struct AnySendableTests {
  @Test("Wraps and unwraps Int values")
  func testIntWrapping() {
    let wrapped = AnySendable(42)
    let unwrapped = wrapped.base as? Int
    #expect(unwrapped == 42)
  }

  @Test("Wraps and unwraps String values")
  func testStringWrapping() {
    let wrapped = AnySendable("hello")
    let unwrapped = wrapped.base as? String
    #expect(unwrapped == "hello")
  }

  @Test("Wraps and unwraps Array values")
  func testArrayWrapping() {
    let wrapped = AnySendable([1, 2, 3])
    let unwrapped = wrapped.base as? [Int]
    #expect(unwrapped == [1, 2, 3])
  }

  @Test("Equality works for same type and value")
  func testEquality() {
    let a = AnySendable(42)
    let b = AnySendable(42)
    #expect(a == b)
  }

  @Test("Inequality works for same type different value")
  func testInequality() {
    let a = AnySendable(42)
    let b = AnySendable(99)
    #expect(a != b)
  }

  @Test("Inequality works for different types")
  func testDifferentTypes() {
    let a = AnySendable(42)
    let b = AnySendable("42")
    #expect(a != b)
  }

  @Test("Hashable conformance allows use in Set")
  func testHashable() {
    let set: Set<AnySendable> = [
      AnySendable(42),
      AnySendable("hello"),
      AnySendable(42),
    ]
    #expect(set.count == 2)
  }

  @Test("CustomStringConvertible provides description")
  func testDescription() {
    let wrapped = AnySendable(42)
    #expect(wrapped.description == "42")
  }

  @Test("CustomDebugStringConvertible provides debug description")
  func testDebugDescription() {
    let wrapped = AnySendable(42)
    #expect(wrapped.debugDescription.contains("AnySendable"))
    #expect(wrapped.debugDescription.contains("Int"))
    #expect(wrapped.debugDescription.contains("42"))
  }

  @Test("Heterogeneous collection storage")
  func testHeterogeneousCollection() {
    let values: [AnySendable] = [
      AnySendable(42),
      AnySendable("hello"),
      AnySendable(true),
      AnySendable([1, 2, 3]),
    ]

    #expect(values.count == 4)
    #expect(values[0].base is Int)
    #expect(values[1].base is String)
    #expect(values[2].base is Bool)
    #expect(values[3].base is [Int])
  }

  @Test("Pattern matching on base value")
  func testPatternMatching() {
    let wrapped = AnySendable(42)

    var matched = false
    switch wrapped.base {
    case let int as Int:
      #expect(int == 42)
      matched = true

    default:
      break
    }

    #expect(matched)
  }
}
